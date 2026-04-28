-- ------------------------------------------------------------
-- Query 1: Schema & Sample Data
--
-- This file defines the schema for a hybrid documentation
-- search system and populates it with sample records.
--
-- The schema mirrors the real docs.surrealdb.com search index:
--   • page     — one record per documentation page
--   • section  — one record per H2 heading within a page
--
-- Embeddings here use 4 dimensions for readability.
-- The production system uses 1536-dimensional OpenAI vectors.
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Text analyzer
--
-- A single analyzer is shared across all full-text indexes.
-- Tokenizers fire in sequence on the input text:
--   blank  — split on whitespace
--   class  — split on Unicode character-class transitions
--   camel  — split on camelCase boundaries (e.g. "camelCase" → "camel", "Case")
--   punct  — split on punctuation characters
--
-- The snowball(english) filter then stems each token so that
-- "querying", "queries", and "query" all match the same index entry.
-- ------------------------------------------------------------

DEFINE ANALYZER OVERWRITE simple
    TOKENIZERS blank, class, camel, punct
    FILTERS snowball(english);


-- ------------------------------------------------------------
-- page table
--
-- One record per documentation page. Stores the plain-text
-- content (code blocks excluded), navigation metadata, and
-- a vector embedding for semantic search.
-- ------------------------------------------------------------

DEFINE TABLE OVERWRITE page SCHEMAFULL;

DEFINE FIELD OVERWRITE path         ON page TYPE string;
DEFINE FIELD OVERWRITE collection   ON page TYPE string;  -- e.g. "doc-surrealql", "doc-sdk-javascript"
DEFINE FIELD OVERWRITE title        ON page TYPE string;
DEFINE FIELD OVERWRITE description  ON page TYPE string;
DEFINE FIELD OVERWRITE breadcrumb   ON page TYPE string;  -- "SurrealQL > Statements > SELECT"
DEFINE FIELD OVERWRITE content      ON page TYPE string;  -- plain text, no code blocks
DEFINE FIELD OVERWRITE content_hash ON page TYPE string;  -- SHA-256 for incremental re-indexing
DEFINE FIELD OVERWRITE embedding    ON page TYPE array<float>;  -- 4D here; 1536D in production
DEFINE FIELD OVERWRITE date         ON page TYPE datetime DEFAULT time::now();

-- Unique path index lets the indexer UPSERT by URL
DEFINE INDEX OVERWRITE page_path_unique ON page FIELDS path UNIQUE CONCURRENTLY;
-- Collection index speeds up collection-filtered queries
DEFINE INDEX OVERWRITE page_collection  ON page FIELDS collection CONCURRENTLY;

-- BM25 full-text indexes, one per searchable field.
-- BM25(1.2, 0.75): k1=1.2 controls term-frequency saturation,
--                  b=0.75 controls document-length normalisation.
-- Field weights used at query time (see query-2.surql):
--   title (25) > path (15) > breadcrumb (10) > description (8) > content (3)
DEFINE INDEX OVERWRITE page_ft_title       ON page FIELDS title       FULLTEXT ANALYZER simple BM25(1.2, 0.75) CONCURRENTLY;
DEFINE INDEX OVERWRITE page_ft_breadcrumb  ON page FIELDS breadcrumb  FULLTEXT ANALYZER simple BM25(1.2, 0.75) CONCURRENTLY;
DEFINE INDEX OVERWRITE page_ft_description ON page FIELDS description FULLTEXT ANALYZER simple BM25(1.2, 0.75) CONCURRENTLY;
DEFINE INDEX OVERWRITE page_ft_content     ON page FIELDS content     FULLTEXT ANALYZER simple BM25(1.2, 0.75) CONCURRENTLY;
DEFINE INDEX OVERWRITE page_ft_path        ON page FIELDS path        FULLTEXT ANALYZER simple BM25(1.2, 0.75) CONCURRENTLY;

-- HNSW index for approximate nearest-neighbour vector search.
-- DIST COSINE is the standard metric for normalised text embeddings.
DEFINE INDEX OVERWRITE page_embedding_hnsw ON page FIELDS embedding
    HNSW DIMENSION 4 DIST COSINE CONCURRENTLY;


-- ------------------------------------------------------------
-- section table
--
-- One record per H2 heading within a page. Enables deep-linking
-- to specific sections and independent ranking of section content.
-- The `page` field is a record link with cascade delete, so
-- removing a page automatically removes all its sections.
-- ------------------------------------------------------------

DEFINE TABLE OVERWRITE section SCHEMAFULL;

DEFINE FIELD OVERWRITE page         ON section TYPE record<page>
    REFERENCE ON DELETE CASCADE;
DEFINE FIELD OVERWRITE anchor       ON section TYPE string;  -- URL fragment, e.g. "record-ranges"
DEFINE FIELD OVERWRITE depth        ON section TYPE int;     -- heading depth (always 2)
DEFINE FIELD OVERWRITE title        ON section TYPE string;
DEFINE FIELD OVERWRITE breadcrumb   ON section TYPE string;  -- page breadcrumb + " > " + section title
DEFINE FIELD OVERWRITE content      ON section TYPE string;
DEFINE FIELD OVERWRITE content_hash ON section TYPE string;
DEFINE FIELD OVERWRITE embedding    ON section TYPE array<float>;
DEFINE FIELD OVERWRITE date         ON section TYPE datetime DEFAULT time::now();

-- Unique (page, anchor) prevents duplicate sections per page
DEFINE INDEX OVERWRITE section_page   ON section FIELDS page CONCURRENTLY;
DEFINE INDEX OVERWRITE section_anchor ON section FIELDS page, anchor UNIQUE CONCURRENTLY;

-- Sections search title (25), breadcrumb (10), and content (3)
DEFINE INDEX OVERWRITE section_ft_title      ON section FIELDS title      FULLTEXT ANALYZER simple BM25(1.2, 0.75) CONCURRENTLY;
DEFINE INDEX OVERWRITE section_ft_breadcrumb ON section FIELDS breadcrumb FULLTEXT ANALYZER simple BM25(1.2, 0.75) CONCURRENTLY;
DEFINE INDEX OVERWRITE section_ft_content    ON section FIELDS content    FULLTEXT ANALYZER simple BM25(1.2, 0.75) CONCURRENTLY;

DEFINE INDEX OVERWRITE section_embedding_hnsw ON section FIELDS embedding
    HNSW DIMENSION 4 DIST COSINE CONCURRENTLY;

// To learn more about the search schema used here, see:
// https://surrealdb.com/docs/reference/query-language/statements/define/indexes
