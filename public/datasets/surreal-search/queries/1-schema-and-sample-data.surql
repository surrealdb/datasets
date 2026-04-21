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


-- ------------------------------------------------------------
-- Sample pages
--
-- Each 4D embedding vector encodes a rough semantic position:
--   [query/retrieval, schema/definition, security/auth, performance/indexing]
--
-- These hand-crafted vectors let the examples produce intuitive
-- results: a query vector for "querying data" should rank the
-- SELECT page first, and a "security" vector should rank auth.
-- ------------------------------------------------------------

CREATE page:select CONTENT {
    path:         "/docs/surrealql/statements/select",
    collection:   "doc-surrealql",
    title:        "SELECT",
    description:  "The SELECT statement can be used to retrieve and filter data from tables and records.",
    breadcrumb:   "SurrealQL > Statements > SELECT",
    content:      "The SELECT statement retrieves records from one or more tables. You can filter results with WHERE, sort with ORDER BY, limit with LIMIT, and traverse graph edges inline.",
    content_hash: "hash-select-v1",
    embedding:    [0.9, 0.2, 0.05, 0.15]
};

CREATE page:define_table CONTENT {
    path:         "/docs/surrealql/statements/define/table",
    collection:   "doc-surrealql",
    title:        "DEFINE TABLE",
    description:  "The DEFINE TABLE statement defines the schema for a table, including field types, indexes, and permissions.",
    breadcrumb:   "SurrealQL > Statements > DEFINE > TABLE",
    content:      "Use DEFINE TABLE to declare a table as SCHEMAFULL or SCHEMALESS, define field types, set up indexes, and configure access permissions using the PERMISSIONS clause.",
    content_hash: "hash-define-table-v1",
    embedding:    [0.15, 0.9, 0.1, 0.3]
};

CREATE page:authentication CONTENT {
    path:         "/docs/surrealdb/security/authentication",
    collection:   "doc-surrealdb",
    title:        "Authentication",
    description:  "SurrealDB supports system users (RBAC) and record users (custom signup/signin logic).",
    breadcrumb:   "SurrealDB > Security > Authentication",
    content:      "SurrealDB has two authentication models: system users defined with DEFINE USER and governed by RBAC roles, and record users defined with DEFINE ACCESS that support custom signup and signin logic and fine-grained permissions.",
    content_hash: "hash-auth-v1",
    embedding:    [0.1, 0.2, 0.95, 0.05]
};

CREATE page:indexes CONTENT {
    path:         "/docs/surrealql/statements/define/indexes",
    collection:   "doc-surrealql",
    title:        "Indexes",
    description:  "SurrealDB supports unique, full-text (BM25), and vector (HNSW) indexes for fast lookups and search.",
    breadcrumb:   "SurrealQL > Statements > DEFINE > INDEX",
    content:      "DEFINE INDEX creates an index on one or more fields. Use UNIQUE for uniqueness constraints, FULLTEXT with BM25 for full-text search, and HNSW for approximate nearest-neighbour vector search with cosine or euclidean distance.",
    content_hash: "hash-indexes-v1",
    embedding:    [0.25, 0.55, 0.05, 0.9]
};

CREATE page:relate CONTENT {
    path:         "/docs/surrealql/statements/relate",
    collection:   "doc-surrealql",
    title:        "RELATE",
    description:  "The RELATE statement creates a graph edge between two records, enabling graph traversal queries.",
    breadcrumb:   "SurrealQL > Statements > RELATE",
    content:      "RELATE creates a directed edge between two records using the syntax RELATE source->edge->target. You can store metadata on the edge and traverse it with SELECT ->edge->target FROM source.",
    content_hash: "hash-relate-v1",
    embedding:    [0.75, 0.35, 0.05, 0.1]
};


-- ------------------------------------------------------------
-- Sample sections
--
-- Sections belong to pages via record link and are identified
-- by a (page, anchor) pair. The URL is page.path + "#" + anchor.
-- ------------------------------------------------------------

CREATE section:select_basic CONTENT {
    page:         page:select,
    anchor:       "basic-usage",
    depth:        2,
    title:        "Basic usage",
    breadcrumb:   "SurrealQL > Statements > SELECT > Basic usage",
    content:      "The simplest SELECT query retrieves all fields from all records in a table: SELECT * FROM person. You can project specific fields: SELECT name, age FROM person.",
    content_hash: "hash-select-basic-v1",
    embedding:    [0.95, 0.1, 0.0, 0.05]
};

CREATE section:select_where CONTENT {
    page:         page:select,
    anchor:       "filtering-with-where",
    depth:        2,
    title:        "Filtering with WHERE",
    breadcrumb:   "SurrealQL > Statements > SELECT > Filtering with WHERE",
    content:      "Use the WHERE clause to filter records by conditions. Supports comparison operators, AND, OR, NOT, and nested conditions.",
    content_hash: "hash-select-where-v1",
    embedding:    [0.85, 0.15, 0.0, 0.1]
};

CREATE section:define_table_permissions CONTENT {
    page:         page:define_table,
    anchor:       "permissions",
    depth:        2,
    title:        "Table permissions",
    breadcrumb:   "SurrealQL > Statements > DEFINE > TABLE > Table permissions",
    content:      "The PERMISSIONS clause restricts what record users can do. Use WHERE id = $auth.id to limit each user to their own records. System users are not affected by table permissions.",
    content_hash: "hash-define-table-perms-v1",
    embedding:    [0.1, 0.6, 0.7, 0.05]
};

CREATE section:auth_record_access CONTENT {
    page:         page:authentication,
    anchor:       "record-users",
    depth:        2,
    title:        "Record users",
    breadcrumb:   "SurrealDB > Security > Authentication > Record users",
    content:      "Record users are defined with DEFINE ACCESS TYPE RECORD. You provide a SIGNUP expression that creates a new user record and a SIGNIN expression that validates credentials.",
    content_hash: "hash-auth-record-v1",
    embedding:    [0.1, 0.3, 0.95, 0.05]
};

CREATE section:indexes_hnsw CONTENT {
    page:         page:indexes,
    anchor:       "vector-hnsw",
    depth:        2,
    title:        "Vector indexes (HNSW)",
    breadcrumb:   "SurrealQL > Statements > DEFINE > INDEX > Vector indexes (HNSW)",
    content:      "HNSW (Hierarchical Navigable Small World) is an approximate nearest-neighbour algorithm. Specify HNSW DIMENSION N DIST COSINE. Query with the KNN operator: WHERE embedding <|k,ef|> $vector.",
    content_hash: "hash-indexes-hnsw-v1",
    embedding:    [0.3, 0.5, 0.0, 0.95]
};

CREATE section:relate_traversal CONTENT {
    page:         page:relate,
    anchor:       "graph-traversal",
    depth:        2,
    title:        "Graph traversal",
    breadcrumb:   "SurrealQL > Statements > RELATE > Graph traversal",
    content:      "After creating edges with RELATE, traverse them in SELECT using arrow syntax: SELECT ->knows->person FROM person:alice. Use <- for inbound edges and <-> for both directions.",
    content_hash: "hash-relate-traversal-v1",
    embedding:    [0.8, 0.2, 0.0, 0.1]
};

// To learn more about the search schema used here, see:
// https://surrealdb.com/docs/reference/query-language/statements/define/indexes
