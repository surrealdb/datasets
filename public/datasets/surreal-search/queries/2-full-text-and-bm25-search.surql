-- ------------------------------------------------------------
-- Query 2: Full-Text BM25 Search
--
-- Run query-1.surql first to set up the schema and sample data.
--
-- BM25 (Best Match 25) is a ranking function that scores how
-- relevant a document is to a query based on term frequency
-- and document length. SurrealDB exposes it through:
--   • @N@ operator — matches documents where field N contains
--                    the search terms (N binds to search::score(N))
--   • search::score(N) — returns the BM25 relevance score for
--                         the N-th search predicate in a query
--
-- Field weights used by the real docs search handler:
--   title (25) — strongest signal: exact topic match
--   path  (15) — URL keywords are reliable ("statements/select")
--   breadcrumb (10) — navigation context
--   description (8) — frontmatter summary
--   content (3) — body text: weaker per-term but highest volume
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Page full-text search
--
-- Five @N@ predicates bind to search::score(0..4) in order.
-- Each score is multiplied by its weight, then summed into
-- ft_score. Results are ranked by this combined score.
-- ------------------------------------------------------------

"Page full-text search for 'select statement':";
SELECT
    title,
    breadcrumb,
    (
        (search::score(0) * 15)   -- path weight
        + (search::score(1) * 25) -- title weight (strongest)
        + (search::score(2) * 10) -- breadcrumb weight
        + (search::score(3) * 8)  -- description weight
        + (search::score(4) * 3)  -- content weight (weakest)
    ) AS ft_score
FROM page
WHERE
    path        @0@ "select"
    OR title        @1@ "select"
    OR breadcrumb   @2@ "select"
    OR description  @3@ "select"
    OR content      @4@ "select"
ORDER BY ft_score DESC
LIMIT 5;


-- ------------------------------------------------------------
-- BM25 and the snowball stemmer
--
-- The `simple` analyzer stems tokens before indexing, so a query
-- for "querying" matches documents containing "query", "queries",
-- and "queried" — they all stem to the same root form.
-- ------------------------------------------------------------

"Stemming: 'querying' matches 'query', 'queries', 'queried':";
SELECT title, (search::score(0) * 25) AS title_score
FROM page
WHERE title @0@ "querying"
ORDER BY title_score DESC;

"Stemming: 'defining' matches 'define', 'defined', 'definitions':";
SELECT title, (search::score(0) * 25) AS title_score
FROM page
WHERE title @0@ "defining"
ORDER BY title_score DESC;


-- ------------------------------------------------------------
-- Multi-keyword search
--
-- BM25 rewards documents that contain more of the query terms
-- and penalises very long documents (length normalisation).
-- Searching "define index vector" should score the Indexes page
-- above the DEFINE TABLE page even though both mention "define".
-- ------------------------------------------------------------

"Multi-keyword search: 'define index vector':";
SELECT
    title,
    (
        (search::score(0) * 15)
        + (search::score(1) * 25)
        + (search::score(2) * 10)
        + (search::score(3) * 8)
        + (search::score(4) * 3)
    ) AS ft_score
FROM page
WHERE
    path        @0@ "define index vector"
    OR title        @1@ "define index vector"
    OR breadcrumb   @2@ "define index vector"
    OR description  @3@ "define index vector"
    OR content      @4@ "define index vector"
ORDER BY ft_score DESC
LIMIT 5;


-- ------------------------------------------------------------
-- Section full-text search
--
-- Sections only have three searchable fields (no path or description).
-- The title weight remains the highest signal.
-- ------------------------------------------------------------

"Section full-text search for 'permissions':";
SELECT
    title,
    breadcrumb,
    (
        (search::score(0) * 25) -- title weight
        + (search::score(1) * 10) -- breadcrumb weight
        + (search::score(2) * 3)  -- content weight
    ) AS ft_score
FROM section
WHERE
    title       @0@ "permissions"
    OR breadcrumb   @1@ "permissions"
    OR content      @2@ "permissions"
ORDER BY ft_score DESC
LIMIT 5;


-- ------------------------------------------------------------
-- camelCase tokenizer in action
--
-- The `camel` tokenizer splits on camelCase boundaries, so
-- "DEFINE TABLE" stored in camelCase fields or identifiers like
-- "contentHash" → ["content", "Hash"] are both searchable.
-- ------------------------------------------------------------

"camelCase split: searching 'hash' finds 'contentHash' content:";
SELECT title, (search::score(0) * 3) AS content_score
FROM page
WHERE content @0@ "hash"
ORDER BY content_score DESC;

// To learn more about full-text search in SurrealDB, visit:
// https://surrealdb.com/docs/reference/query-language/statements/define/indexes
