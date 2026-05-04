-- ------------------------------------------------------------
-- Query 5: Incremental Indexing
--
-- Run query-1.surql first to set up the schema and sample data.
--
-- Re-embedding every document on every indexer run is expensive
-- (OpenAI API calls add up quickly at scale). The search indexer
-- avoids this by storing a SHA-256 content_hash on each record
-- and comparing it against the hash of the current file content.
-- Only records whose hash has changed are re-embedded and upserted.
--
-- The four phases of the real indexer (indexer.ts):
--   1. Fetch existing hashes  — compare to detect changes
--   2. Crawl current content  — compute hashes for live files
--   3. Embed & UPSERT changed — only pay for what changed
--   4. Delete stale records   — clean up removed pages
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Phase 1: Fetch existing content hashes
--
-- Before crawling, the indexer loads every record's current hash.
-- This lets it skip any record whose content hasn't changed since
-- the last indexing run.
-- ------------------------------------------------------------

"Phase 1 — Current content hashes in the index:";
SELECT id, content_hash FROM page;
SELECT id, content_hash FROM section;


-- ------------------------------------------------------------
-- Phase 2: Simulate a content change
--
-- Imagine the SELECT page has been updated — new examples added,
-- description rewritten. The crawler produces a new hash that
-- differs from the stored one, so this record is queued for
-- re-embedding and upsert.
-- ------------------------------------------------------------

"Phase 2 — Detect a changed page (hash mismatch):";
LET $new_hash = "hash-select-v2";  -- new SHA-256 from the crawler

SELECT id, content_hash,
    -- True when the stored hash differs from the incoming hash
    (content_hash != $new_hash) AS needs_reindex
FROM page
WHERE id = page:select;


-- ------------------------------------------------------------
-- Phase 3: UPSERT changed records
--
-- UPSERT MERGE creates the record if it doesn't exist or updates
-- only the specified fields if it does. This is safe to run
-- repeatedly — unchanged fields are not overwritten.
--
-- In production the embedding array comes from the OpenAI API.
-- Here we use a placeholder vector to show the upsert pattern.
-- ------------------------------------------------------------

"Phase 3 — Upsert the updated SELECT page:";
UPSERT page:select MERGE {
    title:        "SELECT",
    description:  "The SELECT statement retrieves and filters records. Supports subqueries, graph traversal, and value projections.",
    content:      "SELECT retrieves records from tables. Filter with WHERE, sort with ORDER BY, limit with LIMIT, paginate with START, and traverse graph edges inline. Subqueries and value projections are also supported.",
    content_hash: "hash-select-v2",
    -- In production this would be a fresh 1536D embedding from OpenAI.
    -- We update the vector to reflect the changed content.
    embedding:    [0.92, 0.18, 0.04, 0.13],
    date:         time::now()
};

-- Verify the hash and content were updated
"Verify — updated record:";
SELECT id, title, content_hash, date FROM page WHERE id = page:select;


-- ------------------------------------------------------------
-- UPSERT a brand-new page (not yet in the index)
--
-- The same UPSERT MERGE statement handles both inserts and updates,
-- so the indexer uses a single code path regardless of whether a
-- page is new or modified.
-- ------------------------------------------------------------

"Phase 3 — Upsert a newly added page:";
UPSERT page:live_queries MERGE {
    path:         "/docs/surrealql/statements/live",
    collection:   "doc-surrealql",
    title:        "LIVE SELECT",
    description:  "LIVE SELECT streams real-time notifications when matching records change.",
    breadcrumb:   "SurrealQL > Statements > LIVE SELECT",
    content:      "LIVE SELECT subscribes to changes on a table or record. The server pushes CREATE, UPDATE, and DELETE notifications to connected clients whenever a matching record changes.",
    content_hash: "hash-live-queries-v1",
    embedding:    [0.85, 0.2, 0.05, 0.2],
    date:         time::now()
};

"New page is now searchable:";
SELECT id, title, path, date FROM page ORDER BY date DESC LIMIT 3;


-- ------------------------------------------------------------
-- Phase 4: Remove stale records
--
-- Pages that were deleted or renamed in the source docs no longer
-- appear in the crawl output. The indexer collects their record IDs
-- and deletes them. Sections are removed automatically because
-- the `page` field carries an ON DELETE CASCADE reference.
-- ------------------------------------------------------------

-- Simulate: the RELATE page was removed from the docs source
LET $stale_page_ids = [page:relate];

"Phase 4 — Delete stale page(s):";
DELETE FROM page WHERE id IN $stale_page_ids;

-- Confirm the page is gone
"Remaining pages after cleanup:";
SELECT id, title FROM page ORDER BY id;

-- Sections that belonged to the deleted page are cascade-deleted.
-- Verify no orphaned sections remain for the removed page:
"Cascade delete — no sections should remain for the deleted page:";
SELECT id, title FROM section WHERE page = page:relate;

// To learn more about UPSERT in SurrealDB, visit:
// https://surrealdb.com/docs/reference/query-language/statements/upsert
