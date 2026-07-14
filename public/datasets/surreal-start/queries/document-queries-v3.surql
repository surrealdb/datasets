-- ------------------------------------------------------------
-- Document queries (v3)
--
-- SurrealDB is a document database at heart: records are stored as
-- flexible, JSON-like documents instead of rigid rows and columns.
-- This file walks through the core ideas of document modelling:
--
--   1. Schemaless documents — self-describing records with nested
--                             objects and arrays, no schema required.
--
--   2. Embedding vs linking — nested data lives inside a document,
--                             while linked data is referenced by id.
--
--   3. SCHEMAFULL + FLEXIBLE — adding structure and validation while
--                             still allowing free-form nested data.
--
-- Learn more: https://surrealdb.com/docs/surrealdb/models/document
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 1. SCHEMALESS DOCUMENTS
--
-- Without a DEFINE TABLE/FIELD schema, a table is schemaless by
-- default — every record can have its own shape.
-- ------------------------------------------------------------

CREATE user CONTENT {
    name: "Alice Smith",
    email: "alice@example.com",
    age: 29,
    addresses: [
        { type: "home", city: "Springfield", country: "USA" },
        { type: "work", city: "Metropolis", country: "USA" }
    ]
};

-- A second user with a completely different shape — schemaless
-- tables happily store documents that don't match one another
CREATE user CONTENT {
    name: "Ignacio Fernández",
    email: "ignacio@example.com",
    preferences: { newsletter: true, theme: "dark" }
};

SELECT * FROM user;

-- Reach into nested objects and arrays with dot / index paths.
-- Ignacio has no `addresses` field, so his `home_city` is simply NONE
SELECT name, addresses[0].city AS home_city FROM user;

-- Update a nested field directly, and append to a nested array
UPDATE user SET addresses[0].city = "Shelbyville" WHERE name = "Alice Smith";
UPDATE user SET addresses += { type: "billing", city: "Capital City", country: "USA" }
    WHERE name = "Alice Smith";


-- ------------------------------------------------------------
-- 2. EMBEDDING VS LINKING
--
-- Related data can either be embedded directly inside a document, or
-- linked by storing another record's id and dereferencing it on read.
-- ------------------------------------------------------------

-- Embedding: comments live inside the article document itself
CREATE article:embedded_demo CONTENT {
    title: "Thinking in documents",
    comments: [
        { author: "Sam",   text: "Great overview!" },
        { author: "Priya", text: "Clears up a lot of confusion." }
    ]
};

-- Filter inside an embedded array with a bracket condition
SELECT title, comments[WHERE author = "Sam"] FROM article:embedded_demo;

-- Linking: the author is its own record, referenced by id
CREATE person:jules SET name = "Jules Verne", country = "France";
CREATE article:linked_demo SET title = "20,000 Leagues", author = person:jules;

-- Dereference the link with a dot path — resolved as part of the query
SELECT title, author.name, author.country FROM article:linked_demo;

-- FETCH resolves the whole linked record instead of one field at a time
SELECT * FROM article:linked_demo FETCH author;


-- ------------------------------------------------------------
-- 3. SCHEMAFULL TABLES + FLEXIBLE NESTED DATA
--
-- A SCHEMAFULL table validates every top-level field you define.
-- FLEXIBLE relaxes that rule for a single object (or array of
-- objects) field, so it keeps accepting arbitrary, undeclared keys —
-- structure where you need it, freedom where you don't.
-- ------------------------------------------------------------

DEFINE TABLE product SCHEMAFULL;
DEFINE FIELD name     ON product TYPE string;
DEFINE FIELD price    ON product TYPE number ASSERT $value >= 0;
-- `metadata` stays free-form: different products carry different specs
DEFINE FIELD metadata ON product TYPE object FLEXIBLE;

CREATE product CONTENT {
    name: "Wireless Mouse",
    price: 25.99,
    metadata: { color: "black", dpi: 1600, wireless: true }
};

CREATE product CONTENT {
    name: "Mechanical Keyboard",
    price: 89.50,
    metadata: { layout: "ISO", switches: "brown" }
};

SELECT * FROM product;


-- ------------------------------------------------------------
-- v2 vs v3: SCHEMAFULL strictness on undeclared fields
--
-- Without FLEXIBLE, a SCHEMAFULL table only stores fields you've
-- defined with DEFINE FIELD. What happens to the rest differs by version:
--
--   v2 — undeclared fields were silently dropped (see the v2 dataset)
--   v3 — undeclared fields now raise an error
-- ------------------------------------------------------------

DEFINE TABLE strict_product SCHEMAFULL;
DEFINE FIELD name ON strict_product TYPE string;

-- Uncomment to see it: `sku` isn't defined on strict_product, so 3.x
-- rejects the whole statement instead of silently dropping the field
-- CREATE strict_product CONTENT { name: "Desk Lamp", sku: "DL-100" };
-- => "Found field 'sku', but no such field exists for table 'strict_product'"

-- Destructure the CONTENT down to only defined fields to intentionally
-- ignore extras — this keeps 2.x's forgiving behaviour where you want it
CREATE strict_product CONTENT { name: "Desk Lamp", sku: "DL-100" }.{ name };

SELECT * FROM strict_product;

// To learn more about the document model in SurrealDB, visit:
// https://surrealdb.com/docs/surrealdb/models/document
