-- ------------------------------------------------------------
-- Relational queries (v3)
--
-- SurrealDB can model data the way a traditional relational database
-- does: SCHEMAFULL tables with typed columns, foreign-key-style links
-- between tables, constraints, indexes, and multi-table transactions.
-- Instead of a SQL JOIN, a SELECT just dereferences the linked record.
--
-- Learn more: https://surrealdb.com/docs/surrealdb/models
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 1. TABLES & FOREIGN-KEY-STYLE LINKS
--
-- A `record<table>` field behaves like a foreign key: it stores the
-- id of a row in another table, ready to be dereferenced later.
-- ------------------------------------------------------------

DEFINE TABLE customer SCHEMAFULL;
DEFINE FIELD name  ON customer TYPE string;
DEFINE FIELD email ON customer TYPE string ASSERT string::is_email($value);

DEFINE TABLE product SCHEMAFULL;
DEFINE FIELD name  ON product TYPE string;
DEFINE FIELD price ON product TYPE number ASSERT $value >= 0;
DEFINE FIELD stock ON product TYPE int ASSERT $value >= 0;

-- `customer` behaves like a foreign key on `purchase`. Adding REFERENCE
-- (stable by default since 3.0) also makes the link bidirectional and
-- lets SurrealDB enforce what happens when the target is deleted.
DEFINE TABLE purchase SCHEMAFULL;
DEFINE FIELD customer ON purchase TYPE record<customer> REFERENCE ON DELETE CASCADE;
DEFINE FIELD product  ON purchase TYPE record<product>;
DEFINE FIELD quantity ON purchase TYPE int ASSERT $value > 0;
DEFINE FIELD total    ON purchase TYPE number ASSERT $value >= 0;
DEFINE FIELD created  ON purchase TYPE datetime DEFAULT time::now();

-- Incoming references are picked up automatically as a computed field
DEFINE FIELD purchases ON customer COMPUTED <~purchase;

-- Keep emails unique, and make "this customer's purchases" lookups fast
DEFINE INDEX customer_email    ON customer FIELDS email UNIQUE;
DEFINE INDEX purchase_customer ON purchase FIELDS customer;


-- ------------------------------------------------------------
-- 2. INSERTING RELATED DATA
-- ------------------------------------------------------------

CREATE customer:alice SET name = "Alice Smith", email = "alice@example.com";
CREATE customer:bilal SET name = "Bilal Ahmed", email = "bilal@example.com";

CREATE product:mouse    SET name = "Wireless Mouse",      price = 25.99, stock = 100;
CREATE product:keyboard SET name = "Mechanical Keyboard", price = 89.50, stock = 40;

CREATE purchase SET customer = customer:alice, product = product:mouse,    quantity = 2, total = 51.98;
CREATE purchase SET customer = customer:alice, product = product:keyboard, quantity = 1, total = 89.50;
CREATE purchase SET customer = customer:bilal, product = product:mouse,    quantity = 1, total = 25.99;


-- ------------------------------------------------------------
-- 3. "JOINS" VIA RECORD LINKS
--
-- Instead of a SQL JOIN, dereference the linked record with a dot
-- path — SurrealDB resolves it as part of the same query.
-- ------------------------------------------------------------

-- Pull fields from both sides of the relationship in one query
SELECT customer.name AS customer, product.name AS product, quantity, total
    FROM purchase;

-- FETCH resolves the full linked record instead of one field at a time
SELECT * FROM purchase FETCH customer, product;

-- Filter using a field on the linked record
SELECT * FROM purchase WHERE customer.name = "Alice Smith";


-- ------------------------------------------------------------
-- 4. AGGREGATION
--
-- Classic relational reporting: total spend and order count per customer.
-- ------------------------------------------------------------

SELECT customer.name AS customer, orders, total_spent FROM (
    SELECT customer, count() AS orders, math::sum(total) AS total_spent
    FROM purchase
    GROUP BY customer
);


-- ------------------------------------------------------------
-- 5. TRANSACTIONS
--
-- Wrap statements across tables in a transaction so they succeed or
-- fail together — classic relational atomicity.
-- ------------------------------------------------------------

BEGIN TRANSACTION;

    LET $qty  = 3;
    LET $item = SELECT * FROM ONLY product:mouse;

    -- Guard against overselling before committing to the purchase
    IF $item.stock < $qty {
        THROW "Not enough stock for " + $item.name;
    };

    UPDATE product:mouse SET stock -= $qty;
    CREATE purchase SET
        customer = customer:bilal,
        product  = product:mouse,
        quantity = $qty,
        total    = $item.price * $qty;

COMMIT TRANSACTION;

-- If any statement inside a transaction fails or hits CANCEL, every
-- change made inside it is rolled back — including the stock update:
-- BEGIN TRANSACTION;
--     UPDATE product:mouse SET stock -= 9999; -- would violate the >= 0 ASSERT
-- CANCEL TRANSACTION;


-- ------------------------------------------------------------
-- 6. REFERENTIAL INTEGRITY IN ACTION
--
-- Because `purchase.customer` was declared with REFERENCE ON DELETE
-- CASCADE above, SurrealDB keeps the relationship consistent for you —
-- no DEFINE EVENT required. (Pre-3.0, this needed a DEFINE EVENT, and
-- record references were only available experimentally, gated behind
-- `--allow-experimental record_references`; see the v2 dataset.)
-- ------------------------------------------------------------

CREATE customer:temp SET name = "Temp Customer", email = "temp@example.com";
CREATE purchase SET customer = customer:temp, product = product:mouse, quantity = 1, total = 25.99;

-- The reverse lookup is just a normal field now — no manual query needed
SELECT purchases FROM customer:temp;

-- Deleting the customer automatically cascades to their purchase history
DELETE customer:temp;
SELECT * FROM purchase WHERE customer = customer:temp;

-- Prefer to block the deletion instead of cascading? Swap in ON DELETE REJECT:
-- DEFINE FIELD OVERWRITE customer ON purchase TYPE record<customer> REFERENCE ON DELETE REJECT;

// To learn more about record references and relationships in SurrealDB, visit:
// https://surrealdb.com/docs/surrealql/datamodel/references
// https://surrealdb.com/docs/surrealdb/models/graph
