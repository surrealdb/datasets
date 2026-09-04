---
{
  "panels": {},
  "studio": "notebook/1"
}
---

# Surreal Start: AI

You are about to build the smallest useful piece of an AI application: a knowledge base that can be searched by *meaning*. By the end you will have stored text with embeddings, searched it with a vector index, combined that with keyword search, used the graph to recommend what to read next, and exposed the whole thing as a function and an HTTP endpoint - all inside SurrealDB, in SurrealQL.

Every query lives in a block below. Read the words above it, press **Run Query**, and look at what comes back before moving on. The blocks build on each other, so run them in order. Everything is written into three small tables that the last block removes again.

> [!tip]
> Press the `</>` button in the top right to see the markdown behind this document, and press it again to come back. Every block is plain JSON, so you can copy one, change the query and make the notebook your own.

> [!important]
> This notebook needs SurrealDB 3.x, and a connection to a namespace and database you can write to. Nothing here touches tables you already have.

---

## 1. Say hello

Make sure the connection works and see where you are. `session::ns()` and `session::db()` answer with the namespace and database this notebook is talking to.

```panel
{
  "type": "query",
  "id": "8231ee49eb6fca18681dceac",
  "state": {
    "queryState": {
      "doc": "RETURN {\n    namespace: session::ns(),\n    database: session::db(),\n    time: time::now()\n};",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

---

## 2. What an embedding is

An **embedding** is a list of numbers that describes the meaning of a piece of text. Texts that mean similar things get lists that point in similar directions, so "how do I connect two records" and "linking records with RELATE" end up close together even though they share no words. A model turns text into these numbers - OpenAI, Voyage, a local model, it does not matter to the database.

Real embeddings have hundreds or thousands of dimensions. To keep them readable, this notebook uses **four**, and gives each one a meaning:

| Position | Stands for |
| --- | --- |
| 1 | querying and reading data |
| 2 | schema and indexes |
| 3 | security and access |
| 4 | graph and relationships |

So `[0.9, 0.1, 0.0, 0.1]` is "mostly about querying", and `[0.0, 0.1, 0.95, 0.0]` is "about security". Start with a table to hold articles and their embeddings. The field type `array<float, 4>` fixes the length, so a vector of the wrong size is refused at the door.

```panel
{
  "type": "query",
  "id": "c8ebebb0e430a6f2e41470d0",
  "state": {
    "queryState": {
      "doc": "DEFINE TABLE OVERWRITE article SCHEMAFULL;\n\nDEFINE FIELD OVERWRITE title ON article TYPE string;\nDEFINE FIELD OVERWRITE body  ON article TYPE string;\nDEFINE FIELD OVERWRITE topic ON article TYPE string;\n\n-- Four dimensions: [querying, schema & indexes, security, graph]\nDEFINE FIELD OVERWRITE embedding ON article TYPE array<float, 4>;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

Now some articles. In a real system the embeddings would come from a model; here they are written by hand along the four axes above, so you can check the search results against them by eye.

```panel
{
  "type": "query",
  "id": "06453c76418226ac7b5fe7ea",
  "state": {
    "queryState": {
      "doc": "INSERT INTO article [\n    {\n        id: article:select,\n        title: \"Reading records with SELECT\",\n        body: \"SELECT reads records from a table. Pick fields, sort them with ORDER BY and page through them with LIMIT and START.\",\n        topic: \"querying\",\n        embedding: [0.95, 0.10, 0.00, 0.05]\n    },\n    {\n        id: article:where,\n        title: \"Filtering with WHERE\",\n        body: \"A WHERE clause keeps only the records that match a condition. Conditions can compare fields, call functions and follow record links.\",\n        topic: \"querying\",\n        embedding: [0.90, 0.05, 0.05, 0.10]\n    },\n    {\n        id: article:define_table,\n        title: \"Defining a table\",\n        body: \"DEFINE TABLE creates a table. Make it SCHEMAFULL to allow only the fields you define, or leave it SCHEMALESS to accept anything.\",\n        topic: \"schema\",\n        embedding: [0.15, 0.90, 0.05, 0.05]\n    },\n    {\n        id: article:indexes,\n        title: \"Speeding up queries with indexes\",\n        body: \"DEFINE INDEX builds an index on one or more fields. Indexing a field makes lookups fast, and a UNIQUE index refuses duplicates.\",\n        topic: \"schema\",\n        embedding: [0.30, 0.85, 0.00, 0.05]\n    },\n    {\n        id: article:access,\n        title: \"Letting users sign up and sign in\",\n        body: \"DEFINE ACCESS describes how someone signs up and signs in. A successful sign in returns a token the client sends with every request.\",\n        topic: \"security\",\n        embedding: [0.05, 0.10, 0.95, 0.00]\n    },\n    {\n        id: article:permissions,\n        title: \"Row-level permissions\",\n        body: \"PERMISSIONS on a table decide which records a signed in user may see or change. A user can be limited to the rows they own.\",\n        topic: \"security\",\n        embedding: [0.20, 0.15, 0.90, 0.05]\n    },\n    {\n        id: article:relate,\n        title: \"Linking records with RELATE\",\n        body: \"RELATE creates a graph edge between two records. The edge is a record of its own, so it can carry fields such as a date or a weight.\",\n        topic: \"graph\",\n        embedding: [0.30, 0.10, 0.00, 0.90]\n    },\n    {\n        id: article:traverse,\n        title: \"Walking the graph with arrows\",\n        body: \"The arrow operators follow edges from a record. person->follows->person walks outwards, and <-follows<- walks back the other way.\",\n        topic: \"graph\",\n        embedding: [0.50, 0.05, 0.00, 0.85]\n    }\n];",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

Have a look at what is stored. Each article is a document with a title, a body and a vector, side by side in one record.

```panel
{
  "type": "query",
  "id": "30f819fdf85bc8663d5f6887",
  "state": {
    "queryState": {
      "doc": "SELECT id, title, topic, embedding FROM article;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

---

## 3. Search by meaning, the slow way

To find articles about a question, turn the question into a vector and look for the stored vectors that point the same way. **Cosine similarity** measures exactly that: `1` means the same direction, `0` means unrelated.

Say someone asks *"How do I connect two records to each other?"*. That question is mostly about the graph with a little querying, so its vector is something like `[0.35, 0.05, 0.00, 0.90]`. Without an index the database compares it against every row, which is fine for eight articles and not fine for eight million.

```panel
{
  "type": "query",
  "id": "ab35ace9b92886aba84de943",
  "state": {
    "queryState": {
      "doc": "-- \"How do I connect two records to each other?\" as a vector\nLET $question = [0.35, 0.05, 0.00, 0.90];\n\nSELECT\n    title,\n    topic,\n    vector::similarity::cosine(embedding, $question) AS similarity\nFROM article\nORDER BY similarity DESC\nLIMIT 3;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

The graph articles win, and neither of them contains the word "connect". That is the whole point of searching by meaning.

---

## 4. Add a vector index

An **HNSW index** finds the nearest vectors without visiting every row. It is approximate by design: it explores part of the space and returns the best it found, which is how vector search stays fast at scale. `DIST COSINE` tells it which notion of distance to use, and it matches the similarity you just computed by hand.

```panel
{
  "type": "query",
  "id": "164b56eff61858b56eac8229",
  "state": {
    "queryState": {
      "doc": "DEFINE INDEX OVERWRITE article_embedding ON article\n    FIELDS embedding\n    HNSW DIMENSION 4 DIST COSINE TYPE F32;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

With the index in place, the `<|k, ef|>` operator asks for the `k` nearest neighbours. `ef` is how many candidates the index is allowed to explore on the way; a higher number is more accurate and a little slower. `vector::distance::knn()` returns the distance the index measured, where `0` is identical and `1` is unrelated.

```panel
{
  "type": "query",
  "id": "18c0b4d0be6f23ed17508df0",
  "state": {
    "queryState": {
      "doc": "LET $question = [0.35, 0.05, 0.00, 0.90];\n\nSELECT\n    title,\n    topic,\n    vector::distance::knn() AS distance\nFROM article\nWHERE embedding <|3, 40|> $question\nORDER BY distance;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

> [!tip]
> Change the `3` to another number and run it again. `INFO FOR TABLE article;` shows the index you just defined.

---

## 5. Keywords still matter

Vectors are great at meaning and bad at exact terms. Someone searching for `DEFINE ACCESS` wants the article that literally says it, and a vector might rank a loosely related security article above it. **Full-text search** covers that side, ranking matches with BM25 - the same scoring most search engines use.

An **analyzer** decides how text is cut into words. This one splits on spaces and punctuation, lowercases everything, and stems English words so that "indexing", "indexes" and "index" all count as the same term.

```panel
{
  "type": "query",
  "id": "e05c4312c5db4122ea1daabb",
  "state": {
    "queryState": {
      "doc": "DEFINE ANALYZER OVERWRITE english\n    TOKENIZERS blank, class, punct\n    FILTERS lowercase, snowball(english);\n\nDEFINE INDEX OVERWRITE article_body_search  ON article FIELDS body  FULLTEXT ANALYZER english BM25;\nDEFINE INDEX OVERWRITE article_title_search ON article FIELDS title FULLTEXT ANALYZER english BM25;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

The `@0@` operator matches a field against search terms, and `search::score(0)` is the BM25 score of that match. The number pairs the score with the match, so a query can weigh several fields differently - a hit in the title counts double here.

```panel
{
  "type": "query",
  "id": "a580c87296ef1cf53cdd8811",
  "state": {
    "queryState": {
      "doc": "-- Stemming at work: \"indexing\" also matches \"index\" and \"indexes\"\nSELECT\n    title,\n    search::score(0) + search::score(1) * 2 AS score\nFROM article\nWHERE body @0@ \"indexing\" OR title @1@ \"indexing\"\nORDER BY score DESC;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

Now the two approaches side by side on one question. Nobody wrote the word "join" anywhere, so keywords find nothing - but "join" *means* a graph question, and the vector search finds the right articles anyway.

```panel
{
  "type": "query",
  "id": "5783844e08ba6af16fed78b8",
  "state": {
    "queryState": {
      "doc": "-- Keywords: nothing mentions \"join\"\nSELECT title FROM article\nWHERE body @0@ \"join\" OR title @1@ \"join\";\n\n-- Meaning: \"join\" is a graph question, and these are the graph articles\nLET $join = [0.40, 0.05, 0.00, 0.85];\n\nSELECT title, vector::distance::knn() AS distance\nFROM article\nWHERE embedding <|2, 40|> $join\nORDER BY distance;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

---

## 6. Hybrid search

The best search does both and merges the results. **Reciprocal rank fusion** gives every result a score from its *position* in each list, so an article that ranks well by keyword *and* by meaning rises to the top. `search::rrf` does the merge: hand it the ranked lists, a smoothing constant (60 is the usual choice) and how many results you want back.

```panel
{
  "type": "query",
  "id": "6e27488f67808819acf790e5",
  "state": {
    "queryState": {
      "doc": "LET $terms  = \"select records\";\nLET $vector = [0.90, 0.10, 0.00, 0.10];\n\n-- Arm one: keywords, scored with BM25\nLET $by_keyword = (\n    SELECT id, title, search::score(0) + search::score(1) * 2 AS score\n    FROM article\n    WHERE body @0@ $terms OR title @1@ $terms\n    ORDER BY score DESC\n    LIMIT 5\n);\n\n-- Arm two: meaning, scored by vector distance\nLET $by_meaning = (\n    SELECT id, title, vector::distance::knn() AS distance\n    FROM article\n    WHERE embedding <|5, 40|> $vector\n    ORDER BY distance\n    LIMIT 5\n);\n\n-- Fused: one list, ranked by how well each article did in both\nLET $fused = search::rrf([$by_keyword, $by_meaning], 60, 5);\n\nSELECT title, rrf_score AS score FROM $fused;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

---

## 7. Bring in the graph

So far every search started from a vector you typed. Real systems start from what they know about a person, and that knowledge is a graph. Add readers, and record what one of them has read as edges.

```panel
{
  "type": "query",
  "id": "c0eeeaa51a0b7e7338905844",
  "state": {
    "queryState": {
      "doc": "DEFINE TABLE OVERWRITE reader SCHEMAFULL;\nDEFINE FIELD OVERWRITE name ON reader TYPE string;\n\n-- An edge table: a reader has read an article\nDEFINE TABLE OVERWRITE read TYPE RELATION FROM reader TO article;\n\nCREATE reader:ada SET name = \"Ada\";\n\nRELATE reader:ada->read->article:relate;\nRELATE reader:ada->read->article:traverse;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

Now recommend what Ada should read next, in one query. Walk the graph to find what she has read, average those embeddings into a "taste" vector, and ask the index for the nearest articles she has *not* read yet. Document, graph and vector, one statement.

```panel
{
  "type": "query",
  "id": "adea1a66753de60b6b88d2f8",
  "state": {
    "queryState": {
      "doc": "-- What Ada has read, straight off the graph\nLET $seen = (SELECT VALUE ->read->article FROM ONLY reader:ada);\n\n-- Her taste: the average of those articles' embeddings\nLET $vectors = (SELECT VALUE embedding FROM article WHERE id INSIDE $seen);\nLET $taste = array::transpose($vectors).map(|$dimension| math::mean($dimension));\n\n-- The nearest articles she has not read yet\nSELECT title, topic, vector::distance::knn() AS distance\nFROM article\nWHERE embedding <|3, 40|> $taste AND id NOTINSIDE $seen\nORDER BY distance;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

---

## 8. Wrap it in a function

This is the *retrieval* half of retrieval-augmented generation: the application embeds a question, the database returns the passages that answer it, and a language model writes the reply from those passages. Keep the search inside the database as a function, so every client asks the same way.

```panel
{
  "type": "query",
  "id": "c7c0c2545c2fac3398b5cbb2",
  "state": {
    "queryState": {
      "doc": "DEFINE FUNCTION OVERWRITE fn::retrieve($vector: array<float>) {\n    RETURN SELECT title, body, vector::distance::knn() AS distance\n        FROM article\n        WHERE embedding <|3, 40|> $vector\n        ORDER BY distance;\n};\n\n-- \"How do I make sure users only see their own rows?\"\nRETURN fn::retrieve([0.20, 0.10, 0.90, 0.05]);",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

A model wants the passages as one piece of text, with the sources kept beside it so the answer can cite them. Shape the result in the database too.

```panel
{
  "type": "query",
  "id": "9b7a287ce825efb70212646e",
  "state": {
    "queryState": {
      "doc": "LET $passages = fn::retrieve([0.20, 0.10, 0.90, 0.05]);\n\nRETURN {\n    context: array::join($passages.body, \"\\\\n\\\\n\"),\n    sources: $passages.title\n};",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

---

## 9. Expose it as an HTTP endpoint

`DEFINE API` turns that function into a real endpoint, served by the database at `POST /api/<namespace>/<database>/ask`. No server in between: a client sends the question's vector and receives the context and sources as JSON. `api::invoke` calls the endpoint from inside SurrealQL, so you can try it right here.

```panel
{
  "type": "query",
  "id": "a7d13f85f9da26aa75d685d3",
  "state": {
    "queryState": {
      "doc": "DEFINE API OVERWRITE \"/ask\"\n    FOR post\n    MIDDLEWARE api::timeout(5s)\n    PERMISSIONS FULL\n    THEN {\n        LET $vector = $request.body.vector;\n\n        IF $vector = NONE {\n            RETURN {\n                status: 400,\n                body: { error: \"Send the question's embedding as 'vector'\" }\n            };\n        };\n\n        LET $passages = fn::retrieve($vector);\n\n        RETURN {\n            status: 200,\n            body: {\n                context: array::join($passages.body, \"\\\\n\\\\n\"),\n                sources: $passages.title\n            }\n        };\n    };\n\n-- Call it as a client would\napi::invoke(\"/ask\", {\n    method: \"post\",\n    body: { vector: [0.20, 0.10, 0.90, 0.05] }\n});\n\n-- And without a vector\napi::invoke(\"/ask\", { method: \"post\", body: {} });",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

> [!note]
> `PERMISSIONS FULL` makes the endpoint public. Narrow it to an expression such as `$auth.id != NONE` to require a signed in user. The clause sits before `THEN`, which is the order SurrealDB 3 expects.

---

## 10. Real embeddings

Everything above works unchanged with real vectors. Change the `4` in the field and the index to your model's size - `1536` for OpenAI's `text-embedding-3-small`, for example - and let the application compute the vectors. The database never calls a model; it only stores and compares what it is given.

The vector then arrives as a **parameter**. Open the **Parameters** tab of this block: it holds a `vector`, and the query refers to it as `$vector`. That is exactly how an SDK passes one in.

```panel
{
  "type": "query",
  "id": "6bab6daef8d157307be1b121",
  "state": {
    "queryState": {
      "doc": "-- The vector comes from the Parameters tab beside this query\nSELECT title, topic, vector::distance::knn() AS distance\nFROM article\nWHERE embedding <|3, 40|> $vector\nORDER BY distance;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    },
    "paramState": {
      "doc": "{\n    \"vector\": [0.90, 0.10, 0.00, 0.10]\n}",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

---

## 11. Clean up

Optional. This removes everything the notebook created and leaves the database as it found it.

```panel
{
  "type": "query",
  "id": "1e40ab21c409b3c1b4b9e0df",
  "state": {
    "queryState": {
      "doc": "REMOVE TABLE read;\nREMOVE TABLE reader;\nREMOVE TABLE article;\nREMOVE FUNCTION fn::retrieve;\nREMOVE API \"/ask\";\nREMOVE ANALYZER english;",
      "selection": {
        "ranges": [
          {
            "anchor": 0,
            "head": 0
          }
        ],
        "main": 0
      }
    }
  }
}
```

---

## Where to go next

- **Vector search**: https://surrealdb.com/docs/surrealdb/models/vector
- **Full-text search**: https://surrealdb.com/docs/surrealdb/models/full-text-search
- **DEFINE API**: https://surrealdb.com/docs/surrealql/statements/define/api
- **A complete search system**: load the *Surreal Search* dataset from the Datasets page for BM25, HNSW, hybrid ranking and incremental indexing over real documentation pages.
- **SurrealDB University**: https://surrealdb.com/learn

You now have a database that stores documents, searches them by meaning and by keyword, walks a graph and serves an API - which is most of what an AI application needs from one.
