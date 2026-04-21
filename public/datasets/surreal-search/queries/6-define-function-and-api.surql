-- ------------------------------------------------------------
-- Query 6: Search as DEFINE FUNCTION and DEFINE API
--
-- Run query-1.surql first to set up the schema and sample data.
--
-- This file builds a complete, self-contained search layer inside
-- SurrealDB using two complementary statements:
--
--   DEFINE FUNCTION — encapsulates the hybrid retrieval logic so
--     callers don't have to write the BM25 + vector + RRF query
--     themselves. Two variants are defined:
--       fn::search::fulltext($query)        — BM25 only
--       fn::search($query, $qvec)           — BM25 + vector + RRF
--
--   DEFINE API — exposes fn::search as a real HTTP endpoint at
--     /api/:ns/:db/search. Clients send a POST with a JSON body
--     (or a GET with a ?q= param) and receive a structured JSON
--     response. No application middleware layer required.
--
-- Architecture note:
--   SurrealDB cannot call external APIs, so the embedding vector
--   ($qvec) must be computed by the application before calling
--   the function or the API endpoint. The API falls back to
--   BM25-only search when no vector is provided. Here $qvec is a
--   4D placeholder; in production it is a 1536-dimensional float
--   array produced by the OpenAI embeddings API.
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- fn::search::fulltext — BM25-only search
--
-- Useful when a vector embedding is not available (e.g. during
-- indexing health checks or simple admin queries). Searches both
-- pages and sections with the same weighted field scoring used
-- in query-4.surql, fused with RRF so the result ordering is
-- consistent with the hybrid function below.
-- ------------------------------------------------------------

DEFINE FUNCTION OVERWRITE fn::search::fulltext($query: string) {
    LET $page_ft = (
        SELECT
            id,
            "page" AS kind,
            path   AS url,
            path   AS page_path,
            collection,
            title,
            breadcrumb,
            description,
            content,
            (
                (search::score(0) * 15)
                + (search::score(1) * 25)
                + (search::score(2) * 10)
                + (search::score(3) * 8)
                + (search::score(4) * 3)
            ) AS ft_score
        FROM page
        WHERE
            path        @0@ $query
            OR title        @1@ $query
            OR breadcrumb   @2@ $query
            OR description  @3@ $query
            OR content      @4@ $query
        ORDER BY ft_score DESC
        LIMIT 30
    );

    LET $section_ft = (
        SELECT
            id,
            "section" AS kind,
            string::concat(page.path, "#", anchor) AS url,
            page.path       AS page_path,
            page.collection AS collection,
            title,
            breadcrumb,
            content,
            (
                (search::score(0) * 25)
                + (search::score(1) * 10)
                + (search::score(2) * 3)
            ) AS ft_score
        FROM section
        WHERE
            title       @0@ $query
            OR breadcrumb   @1@ $query
            OR content      @2@ $query
        ORDER BY ft_score DESC
        LIMIT 30
    );

    LET $fused = search::rrf([$page_ft, $section_ft], 60, 40);

    RETURN SELECT
        kind,
        url,
        page_path,
        collection,
        title,
        breadcrumb,
        rrf_score AS score
    FROM $fused
    LIMIT 20;
};


-- ------------------------------------------------------------
-- fn::search — Full hybrid search (BM25 + vector + RRF)
--
-- Accepts:
--   $query  string        — the search string for BM25 (question
--                           prefixes already stripped by the caller)
--   $qvec   array<float>  — the embedding vector for the original
--                           query, computed externally (e.g. OpenAI)
--
-- Returns an array of result objects ordered by fused RRF score.
-- ------------------------------------------------------------

DEFINE FUNCTION OVERWRITE fn::search($query: string, $qvec: array<float>) {
    -- Page vector arm
    LET $page_vs = (
        SELECT
            id,
            "page" AS kind,
            path   AS url,
            path   AS page_path,
            collection,
            title,
            breadcrumb,
            description,
            content,
            vector::distance::knn() AS distance
        FROM page
        WHERE embedding <|30,100|> $qvec
        ORDER BY distance ASC
        LIMIT 30
    );

    -- Page BM25 arm
    LET $page_ft = (
        SELECT
            id,
            "page" AS kind,
            path   AS url,
            path   AS page_path,
            collection,
            title,
            breadcrumb,
            description,
            content,
            (
                (search::score(0) * 15)
                + (search::score(1) * 25)
                + (search::score(2) * 10)
                + (search::score(3) * 8)
                + (search::score(4) * 3)
            ) AS ft_score
        FROM page
        WHERE
            path        @0@ $query
            OR title        @1@ $query
            OR breadcrumb   @2@ $query
            OR description  @3@ $query
            OR content      @4@ $query
        ORDER BY ft_score DESC
        LIMIT 30
    );

    -- Section vector arm — record link resolves page.path and page.collection
    LET $section_vs = (
        SELECT
            id,
            "section" AS kind,
            string::concat(page.path, "#", anchor) AS url,
            page.path       AS page_path,
            page.collection AS collection,
            title,
            breadcrumb,
            content,
            vector::distance::knn() AS distance
        FROM section
        WHERE embedding <|30,100|> $qvec
        ORDER BY distance ASC
        LIMIT 30
    );

    -- Section BM25 arm
    LET $section_ft = (
        SELECT
            id,
            "section" AS kind,
            string::concat(page.path, "#", anchor) AS url,
            page.path       AS page_path,
            page.collection AS collection,
            title,
            breadcrumb,
            content,
            (
                (search::score(0) * 25)
                + (search::score(1) * 10)
                + (search::score(2) * 3)
            ) AS ft_score
        FROM section
        WHERE
            title       @0@ $query
            OR breadcrumb   @1@ $query
            OR content      @2@ $query
        ORDER BY ft_score DESC
        LIMIT 30
    );

    -- Fuse all four arms with RRF (k=60, up to 80 candidates)
    LET $fused = search::rrf([$page_ft, $page_vs, $section_ft, $section_vs], 60, 80);

    RETURN SELECT
        kind,
        url,
        page_path,
        collection,
        title,
        breadcrumb,
        rrf_score AS score
    FROM $fused
    LIMIT 60;
};


-- ------------------------------------------------------------
-- DEFINE API — /search HTTP endpoint
--
-- Exposes the search functions as a real HTTP endpoint available
-- at /api/:namespace/:database/search.
--
-- Request formats supported:
--   GET  /api/ns/db/search?q=select+statement
--         — keyword-only, falls back to BM25 search
--   POST /api/ns/db/search  body: { "query": "...", "vector": [...] }
--         — hybrid search when a pre-computed embedding is provided
--   POST /api/ns/db/search  body: { "query": "..." }
--         — keyword-only fallback when no vector is supplied
--
-- The api::timeout(5s) middleware aborts the request if the
-- search query has not completed within 5 seconds, protecting
-- the server from slow queries under heavy load.
--
-- PERMISSIONS FULL makes the endpoint publicly accessible.
-- Narrow this to an expression (e.g. $auth.id != NONE) to
-- require authentication before searching.
-- ------------------------------------------------------------

DEFINE API OVERWRITE "/search"
    FOR get, post
    MIDDLEWARE
        api::timeout(5s),
		api::res::body("json")
    THEN {
        -- Read the query string from the POST body or the GET ?q= param
        LET $q    = $request.body.query ?? $request.query.q ?? "";
        -- The pre-computed embedding vector is optional (POST body only)
        LET $qvec = $request.body.vector;

        -- Reject requests that arrive with no search terms
        IF string::len($q) = 0 {
            RETURN {
                status: 400,
                body: { error: "Missing required parameter: 'query'" }
            };
        };

        -- Use the full hybrid search when the caller provides a vector,
        -- otherwise fall back to BM25-only search.
        LET $results = IF $qvec != NONE {
            fn::search($q, $qvec)
        } ELSE {
            fn::search::fulltext($q)
        };

        RETURN {
            status: 200,
            body: {
                query:   $q,
                results: $results,
                count:   array::len($results)
            }
        };
    }
    PERMISSIONS FULL;


-- ------------------------------------------------------------
-- Call the functions directly
-- ------------------------------------------------------------

-- BM25-only search — no vector needed
"Full-text only search for 'authentication':";
RETURN fn::search::fulltext("authentication");

-- Hybrid search — application provides both the string and
-- the pre-computed embedding vector for the same query
"Hybrid search for 'select records':";
RETURN fn::search("select records", [0.88, 0.18, 0.04, 0.12]);

"Hybrid search for 'define an index':";
RETURN fn::search("define an index", [0.2, 0.55, 0.05, 0.9]);

"Hybrid search for 'record user signup signin':";
RETURN fn::search("record user signup signin", [0.1, 0.25, 0.95, 0.05]);


-- ------------------------------------------------------------
-- Test the API endpoint with api::invoke()
--
-- api::invoke() lets you call a DEFINE API endpoint from within
-- SurrealQL without making a real HTTP request. It accepts the
-- path and an optional request object matching $request's shape.
-- ------------------------------------------------------------

-- GET-style: keyword passed as a query string parameter
"API — GET /search?q=authentication (BM25 fallback):";
api::invoke("/search", { query: { q: "authentication" } });

-- POST-style: keyword-only body, no vector → BM25 fallback
"API — POST /search { query } (BM25 fallback):";
api::invoke("/search", {
    body: { query: "select statement" }
});

-- POST-style: full hybrid search with pre-computed embedding
"API — POST /search { query, vector } (hybrid search):";
api::invoke("/search", {
    body: {
        query:  "select statement",
        vector: [0.88, 0.18, 0.04, 0.12]
    }
});

-- Error case: empty query string → 400 response
"API — POST /search { query: '' } (error response):";
api::invoke("/search", { body: { query: "" } });

-- Inspect what functions and API endpoints are defined
INFO FOR DB;

// To learn more about DEFINE FUNCTION in SurrealDB, visit:
// https://surrealdb.com/docs/surrealql/statements/define/function
//
// To learn more about DEFINE API in SurrealDB, visit:
// https://surrealdb.com/docs/surrealql/statements/define/api
