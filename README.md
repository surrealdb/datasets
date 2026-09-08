# SurrealDB Datasets Repository
This repository houses all SurrealDB datasets which should be available at [datasets.surrealdb.com](https://datasets.surrealdb.com).

These datasets will automatically and dynamically update in Surrealist once changed in this repository and merged into the main branch.

## Notebooks

`public/notebooks` holds the starter notebooks for SurrealDB Studio: markdown documents with live query panels in them, read top to bottom with each query run in turn. The prose is fixed - Studio renders a notebook rather than editing it - while every block is a live query panel a reader can change and run again. They are listed in `notebooks.json`, built from `index.ts` alongside `datasets.json`.

Studio opens the notebook matching the use case picked during account onboarding the first time that account enters a database, and offers all of them from an instance's dashboard under **Guides**. Studio refers to a notebook by its `id`, so ids must stay stable; labels and descriptions are free to change.

Every query in every notebook runs, in order, on SurrealDB 3.x, and the last block of each leaves the database as it found it. A statement that is meant to fail says so in a comment: `-- fails on purpose`.
