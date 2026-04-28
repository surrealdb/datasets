-- ==============================
-- Name: surreal-search
-- Description: A sample dataset showcasing full-text BM25, vector (HNSW) semantic search, hybrid ranking, incremental indexing, and exposing search through a defined function and API.
-- Exported: 2026-04-28T14:30:00Z
-- SurrealDB: 3.0.0
-- ==============================

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
