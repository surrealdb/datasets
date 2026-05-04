-- ------------------------------------------------------------
-- Query 3: Vector Semantic Search (HNSW)
--
-- Run query-1.surql first to set up the schema and sample data.
--
-- Vector search finds documents whose embedding vectors are
-- closest to a query vector, using approximate nearest-neighbour
-- (ANN) search via the HNSW algorithm.
--
-- Key concepts:
--   • Each document is embedded as a point in N-dimensional space.
--     Similar concepts cluster together: "SELECT" and "WHERE" sit
--     near each other, far from "DEFINE INDEX" or "authentication".
--   • At query time the user's question is embedded into the same
--     space and the k nearest stored vectors are returned.
--   • SurrealDB's KNN operator: WHERE embedding <|k,ef|> $vector
--       k  — number of results to return
--       ef — exploration factor (higher = more accurate but slower)
--   • vector::distance::knn() returns the cosine distance for the
--     matched row (populated by the HNSW index scan).
--
-- Reminder: the sample data in query-1.surql uses 4D embeddings:
--   [query/retrieval, schema/definition, security/auth, performance/indexing]
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Basic page vector search
--
-- A query vector close to [0.9, 0.2, 0.05, 0.1] represents a
-- "querying / data retrieval" intent. The SELECT page should rank
-- first because its embedding is [0.9, 0.2, 0.05, 0.15].
-- ------------------------------------------------------------

LET $query_retrieval = [0.9, 0.2, 0.05, 0.1];

"Vector search — query intent: 'data retrieval / querying':";
SELECT
    title,
    breadcrumb,
    vector::distance::knn() AS distance  -- lower = more similar
FROM page
WHERE embedding <|5,20|> $query_retrieval
ORDER BY distance ASC;


-- ------------------------------------------------------------
-- Semantic match vs. keyword miss
--
-- The power of vector search: a user asking "how do I join tables"
-- gets results about RELATE and graph traversal — even though the
-- docs never use the word "join". BM25 would find nothing.
-- ------------------------------------------------------------

-- A vector meaning "graph traversal / joining records"
LET $query_graph = [0.8, 0.3, 0.0, 0.1];

"Keyword miss, vector hit — 'joining tables' finds RELATE:";
-- This BM25 query returns nothing because "join" is not in any page
SELECT title FROM page WHERE title @0@ "join" OR content @0@ "join";

-- But the vector search surfaces the RELATE page semantically
SELECT title, breadcrumb, vector::distance::knn() AS distance
FROM page
WHERE embedding <|3,20|> $query_graph
ORDER BY distance ASC;


-- ------------------------------------------------------------
-- Security / authentication semantic search
-- ------------------------------------------------------------

LET $query_security = [0.05, 0.1, 0.95, 0.0];

"Vector search — query intent: 'authentication / security':";
SELECT
    title,
    breadcrumb,
    vector::distance::knn() AS distance
FROM page
WHERE embedding <|5,20|> $query_security
ORDER BY distance ASC;


-- ------------------------------------------------------------
-- Section vector search with record link traversal
--
-- Sections store a record link to their parent page. The HNSW
-- query returns sections, and the record link lets us inline
-- the page's path and collection without a separate query.
-- The URL is constructed by concatenating page.path + "#" + anchor.
-- ------------------------------------------------------------

LET $query_indexing = [0.2, 0.5, 0.0, 0.95];

"Section vector search — 'indexing / performance':";
SELECT
    title,
    breadcrumb,
    string::concat(page.path, "#", anchor) AS url,  -- deep-link URL
    page.collection AS collection,
    vector::distance::knn() AS distance
FROM section
WHERE embedding <|5,20|> $query_indexing
ORDER BY distance ASC;


-- ------------------------------------------------------------
-- Exploration factor (ef) trade-off
--
-- ef controls how many candidates HNSW explores before returning
-- results. Higher ef → more accurate (fewer missed neighbours)
-- but takes longer. For 5 results from a small index, ef=20 is
-- generous. Production uses ef=100 over 1536D vectors.
-- ------------------------------------------------------------

"Low ef (faster, less accurate):";
SELECT title, vector::distance::knn() AS distance
FROM page
WHERE embedding <|5,10|> $query_retrieval
ORDER BY distance ASC;

"High ef (slower, more accurate):";
SELECT title, vector::distance::knn() AS distance
FROM page
WHERE embedding <|5,50|> $query_retrieval
ORDER BY distance ASC;

// To learn more about vector search in SurrealDB, visit:
// https://surrealdb.com/docs/learn/data-models/vector-search/overview
