# SurrealDB Datasets Repository
This repository houses all SurrealDB datasets which should be available at [datasets.surrealdb.com](https://datasets.surrealdb.com).

These datasets will automatically and dynamically update in Surrealist once changed in this repository and merged into the main branch.

## Notebooks

`public/notebooks` holds onboarding notebooks for SurrealDB Studio: markdown documents with live query panels in them, meant to be read top to bottom with each query run in turn. They are listed in `notebooks.json`, built from `index.ts` alongside `datasets.json`. Studio offers that list to a new account when it first signs in - one notebook per topic, in the order listed - and opens the chosen one in the first database the account connects to. Any of them can also be imported by hand with **Import notebook** from the command palette.