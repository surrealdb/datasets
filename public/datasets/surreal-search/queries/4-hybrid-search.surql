-- ------------------------------------------------------------
-- Query 4: Hybrid Search with Reciprocal Rank Fusion (RRF)
--
-- Run query-1.surql first to set up the schema and sample data.
--
-- Neither BM25 nor vector search alone is optimal:
--   • BM25 excels at exact keyword matches ("DEFINE TABLE")
--     but misses semantic paraphrases ("how to create a schema").
--   • Vector search handles paraphrases well but can rank a
--     vaguely related popular page above a precise keyword match.
--
-- Reciprocal Rank Fusion (RRF) merges multiple ranked lists into
-- one by scoring each result based on its position across lists:
--
--   rrf_score = Σ  1 / (k + rank_in_list)
--               lists
--
-- A result appearing at rank 1 in two lists scores higher than
-- one appearing at rank 1 in only one list. The k constant (60
-- by default) smooths the curve so the difference between rank 1
-- and rank 2 is not overwhelming.
--
-- search::rrf(lists, k, limit) — built-in SurrealDB function:
--   lists  — array of ranked result arrays (LET $... variables)
--   k      — smoothing constant (60 is the standard default)
--   limit  — maximum candidates to include in the fused output
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Parameters (would come from the application layer in production)
-- ------------------------------------------------------------

-- BM25 query string — question prefixes stripped to reduce noise
-- ("how do I select records" → "select records")
LET $query = "select records";

-- Embedding vector for the original user query (4D here; 1536D in production)
-- Represents a "data retrieval / querying" intent
LET $qvec = [0.88, 0.18, 0.04, 0.12];


-- ------------------------------------------------------------
-- Arm 1: Page vector search
--
-- Finds the pages whose embeddings are closest to the query
-- vector. Returns up to 5 candidates (30 in production).
-- ef=20 controls HNSW exploration (100 in production).
-- ------------------------------------------------------------

LET $page_vs = (
    SELECT
        id,
        "page"  AS kind,
        path    AS url,
        path    AS page_path,
        collection,
        title,
        breadcrumb,
        description,
        content,
        vector::distance::knn() AS distance
    FROM page
    WHERE embedding <|5,20|> $qvec
    ORDER BY distance ASC
    LIMIT 5
);

-- ------------------------------------------------------------
-- Arm 2: Page full-text search (BM25)
--
-- Weighted sum of per-field BM25 scores. Field weights reflect
-- how informative each field is as a signal for relevance.
-- ------------------------------------------------------------

LET $page_ft = (
    SELECT
        id,
        "page"  AS kind,
        path    AS url,
        path    AS page_path,
        collection,
        title,
        breadcrumb,
        description,
        content,
        (
            (search::score(0) * 15)   -- path
            + (search::score(1) * 25) -- title (strongest)
            + (search::score(2) * 10) -- breadcrumb
            + (search::score(3) * 8)  -- description
            + (search::score(4) * 3)  -- content (weakest)
        ) AS ft_score
    FROM page
    WHERE
        path        @0@ $query
        OR title        @1@ $query
        OR breadcrumb   @2@ $query
        OR description  @3@ $query
        OR content      @4@ $query
    ORDER BY ft_score DESC
    LIMIT 5
);

-- ------------------------------------------------------------
-- Arm 3: Section vector search
--
-- Same as page vector search but for sections. Uses the record
-- link to inline the parent page's path and collection.
-- The section URL deep-links to the specific heading anchor.
-- ------------------------------------------------------------

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
    WHERE embedding <|5,20|> $qvec
    ORDER BY distance ASC
    LIMIT 5
);

-- ------------------------------------------------------------
-- Arm 4: Section full-text search (BM25)
--
-- Sections don't have path or description fields, so only
-- three fields contribute to the BM25 score.
-- ------------------------------------------------------------

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
            (search::score(0) * 25) -- title
            + (search::score(1) * 10) -- breadcrumb
            + (search::score(2) * 3)  -- content
        ) AS ft_score
    FROM section
    WHERE
        title       @0@ $query
        OR breadcrumb   @1@ $query
        OR content      @2@ $query
    ORDER BY ft_score DESC
    LIMIT 5
);

-- ------------------------------------------------------------
-- RRF fusion
--
-- Merges all four ranked lists. A result that ranks well in
-- multiple arms gets a higher combined score than one that
-- ranks well in only one. The order of the lists matches the
-- production handler: [page_ft, page_vs, section_ft, section_vs].
-- ------------------------------------------------------------

LET $fused = search::rrf([$page_ft, $page_vs, $section_ft, $section_vs], 60, 20);

-- Final result set — rrf_score is the fused ranking signal
"Hybrid search results (BM25 + vector, fused with RRF):";
RETURN (
    SELECT
        kind,
        url,
        page_path,
        collection,
        title,
        breadcrumb,
        rrf_score AS score
    FROM $fused
    LIMIT 10
);


-- ------------------------------------------------------------
-- Inspecting individual arms before fusion
--
-- You can examine each retrieval arm independently to understand
-- what each strategy contributes to the final ranking.
-- ------------------------------------------------------------

"BM25 arm only (exact keyword matching):";
SELECT title, ft_score FROM $page_ft ORDER BY ft_score DESC;

"Vector arm only (semantic similarity):";
SELECT title, distance FROM $page_vs ORDER BY distance ASC;

"RRF fused (both strategies combined):";
SELECT title, rrf_score FROM $fused ORDER BY rrf_score DESC;

// To learn more about hybrid search and RRF in SurrealDB, visit:
// https://surrealdb.com/docs/surrealdb/models/full-text-search
