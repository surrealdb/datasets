# SurrealDB Agent Memory showcase datasets

Each file here holds what the SurrealDB Agent Memory API returned for one of the demos in the [Agent Memory showcase](https://surrealdb.com/docs/agent-memory/cookbooks/showcase), so the records behind a demo can be queried directly.

| File | Demo |
| --- | --- |
| `robin-hood.surql` | [Robin Hood character graph](https://surrealdb.com/docs/agent-memory/cookbooks/showcase/robin-hood) |
| `pompeii.surql` | [Pompeii election notices](https://surrealdb.com/docs/agent-memory/cookbooks/showcase/pompeii) |
| `domesday.surql` | [Domesday: South Erpingham, 1086](https://surrealdb.com/docs/agent-memory/cookbooks/showcase/domesday) |

## What the files contain

The data is the API's response shape: the entities from `GET /entities`, and the attributes and relations from `GET /entities/{type}/{name}`. It is not the data Agent Memory holds internally, which also includes embeddings, source chunks, indexes and other internal tables.

| Table | Holds |
| --- | --- |
| `entity` | One record per entity, with the id the API uses, such as `entity:['person', 'caius_iulius_polybius']` |
| `attribute` | One record per current attribute value, linked to its entity through the `entity` field. `supersedes` holds the id of the value it replaced, which is not itself included, since the entity endpoint returns current values only |
| `relation` | One graph edge per relation, from subject to object, with its `label` |

`robin-hood.surql` also holds the values a later chapter replaced, from `GET /entities/{type}/{name}/history/{key}`, so a replaced value carries a `validUntil` and each attribute's history can be read in order. Its dates are the demo's narrative clock: chapter 1 is 1 January 2000 and each chapter is one day later. A `validUntil` in 2026 marks a value that was closed when the memory was written rather than at a chapter.

Relations are written as graph edges so they can be traversed with `->relation->`, which is the one change from the API's shape. Each attribute and relation keeps the title of the document it came from in `source`.

## Example queries

```surql
-- pompeii.surql: everything known about one person
SELECT key, value, source FROM attribute WHERE entity = entity:['person', 'caius_iulius_polybius'];

-- pompeii.surql: who backs whom
SELECT in.name AS supporter, out.name AS candidate FROM relation WHERE label = 'asks_voters_to_elect';

-- robin-hood.surql: how Robin Hood's temperament changed through the book
SELECT createdAt, value, validUntil, source FROM attribute
    WHERE entity = entity:['person', 'robin_hood'] AND key = 'temperament'
    ORDER BY createdAt;

-- Any file: values that replaced an earlier one
SELECT entity.name AS name, key, value, supersedes FROM attribute WHERE supersedes != NONE;
```
