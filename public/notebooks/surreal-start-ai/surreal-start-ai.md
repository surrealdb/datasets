---
{
  "panels": {},
  "studio": "notebook/1"
}
---

# Surreal Start: AI

You want to give an AI agent a memory, so this guide builds one. By the end you will have a store an agent can write what it learns into and recall from later - by meaning, by how recent and important a memory is, by the exact words in it, and by who or what it is about - wrapped in a function and an HTTP endpoint the agent calls. All of it lives inside SurrealDB, in SurrealQL, because memory needs documents, vectors, a graph and time, and SurrealDB has all four in one place.

**How to read this guide.** Each numbered step explains one idea and then hands you a live query block. Press **Run Query** and look at what comes back before moving on. The steps build on each other, so take them in order. Everything is written into three small tables that the last step removes again.

> [!tip]
> The words on this page are fixed, but the queries are not. Every block is a real query panel: change a vector, ask a different question, run it again and see what comes back.

> [!important]
> This guide needs SurrealDB 3.x and a connection to a namespace and database you can write to. It creates the tables `memory`, `entity` and `about`, a function, an analyzer and an API route, and touches nothing else.

---

## 1. Check where you are

A SurrealDB server holds **namespaces**, a namespace holds **databases**, and a database holds **tables** of **records**. Studio has already chosen a namespace and a database for this connection; `session::ns()` and `session::db()` tell you which.

```panel
{
  "type": "query",
  "id": "00cb98565f8c62a91ddcdced",
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

## 2. What an agent remembers

An agent's memory is text, plus whatever it takes to find the right text again later. Two kinds of memory turn up in every agent: **episodic** memories record what happened - a request, a remark, a decision in a conversation - and **semantic** memories record what is true - a preference, a fact about the user, a fact about the world. Each carries when it was formed, how much it matters, and an **embedding**.

An embedding is a list of numbers that describes the *meaning* of a piece of text. Texts that mean similar things get lists that point in similar directions, so "what should I cook tonight" lands near "Ada is vegetarian" even though they share no words. A model turns text into these numbers - OpenAI, Voyage, a local model, it does not matter to the database.

Real embeddings have hundreds or thousands of dimensions. To keep them readable, this guide uses **four**, and gives each one a meaning:

| Position | Stands for |
| --- | --- |
| 1 | work and projects |
| 2 | travel and places |
| 3 | food and cooking |
| 4 | family and friends |

So `[0.9, 0.0, 0.0, 0.1]` is "mostly about work", and `[0.0, 0.1, 0.95, 0.0]` is "about food". Start with a table to hold memories. The field type `array<float, 4>` fixes the length, so a vector of the wrong size is refused at the door, and `superseded` is there for later - a memory an agent has since corrected stays on record but stops being recalled.

```panel
{
  "type": "query",
  "id": "c324e67e30ed536085e99606",
  "state": {
    "queryState": {
      "doc": "DEFINE TABLE OVERWRITE memory SCHEMAFULL;\n\nDEFINE FIELD OVERWRITE content    ON memory TYPE string;\nDEFINE FIELD OVERWRITE kind       ON memory TYPE string ASSERT $value IN [\"episodic\", \"semantic\"];\nDEFINE FIELD OVERWRITE importance ON memory TYPE float DEFAULT 0.5 ASSERT $value >= 0 AND $value <= 1;\nDEFINE FIELD OVERWRITE created    ON memory TYPE datetime DEFAULT time::now();\nDEFINE FIELD OVERWRITE superseded ON memory TYPE bool DEFAULT false;\n\n-- Four dimensions: [work, travel, food, family]\nDEFINE FIELD OVERWRITE embedding  ON memory TYPE array<float, 4>;",
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

## 3. Store what the agent learns

An assistant has been talking to Ada for a few months. These are the memories it kept, written the way an agent would write them: a sentence, a kind, an importance, and an embedding of the sentence. In a real system the embeddings come from a model; here they are written by hand along the four axes above, so you can check every result against them by eye. The timestamps are spread over the past three months, because *when* something was remembered will matter shortly.

```panel
{
  "type": "query",
  "id": "a200311b601be22861bfed53",
  "state": {
    "queryState": {
      "doc": "INSERT INTO memory [\n    {\n        id: memory:works_at,\n        content: \"Ada works at SurrealDB as a database engineer.\",\n        kind: \"semantic\", importance: 0.9, created: time::now() - 80d,\n        embedding: [0.95, 0.05, 0.00, 0.10]\n    },\n    {\n        id: memory:meetings,\n        content: \"Ada prefers morning meetings and short written updates.\",\n        kind: \"semantic\", importance: 0.6, created: time::now() - 20d,\n        embedding: [0.85, 0.00, 0.00, 0.05]\n    },\n    {\n        id: memory:launch_demo,\n        content: \"Ada asked for help planning a launch demo for the graph feature.\",\n        kind: \"episodic\", importance: 0.6, created: time::now() - 3d,\n        embedding: [0.90, 0.10, 0.00, 0.05]\n    },\n    {\n        id: memory:bob_joining,\n        content: \"Ada mentioned Bob is joining her team next month.\",\n        kind: \"episodic\", importance: 0.5, created: time::now() - 5d,\n        embedding: [0.80, 0.00, 0.00, 0.40]\n    },\n    {\n        id: memory:vegetarian,\n        content: \"Ada is vegetarian and dislikes coriander.\",\n        kind: \"semantic\", importance: 0.8, created: time::now() - 60d,\n        embedding: [0.00, 0.05, 0.95, 0.10]\n    },\n    {\n        id: memory:dahl,\n        content: \"Ada cooked a lentil dahl on Sunday and said it needed more lime.\",\n        kind: \"episodic\", importance: 0.3, created: time::now() - 2d,\n        embedding: [0.00, 0.00, 0.90, 0.20]\n    },\n    {\n        id: memory:sister,\n        content: \"Ada's sister Fay lives in Madrid.\",\n        kind: \"semantic\", importance: 0.7, created: time::now() - 90d,\n        embedding: [0.00, 0.40, 0.00, 0.90]\n    },\n    {\n        id: memory:trip,\n        content: \"Ada is flying to Madrid on Friday to visit Fay.\",\n        kind: \"episodic\", importance: 0.8, created: time::now() - 1d,\n        embedding: [0.05, 0.85, 0.05, 0.50]\n    },\n    {\n        id: memory:weather,\n        content: \"Ada said the weather in London was grey again.\",\n        kind: \"episodic\", importance: 0.1, created: time::now() - 45d,\n        embedding: [0.00, 0.30, 0.00, 0.10]\n    }\n];\n\nSELECT id, kind, importance, created, content FROM memory ORDER BY created;",
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

## 4. Recall by meaning

Ada asks *"What should I cook tonight?"*. To answer, the agent turns the question into a vector and looks for the stored vectors that point the same way. **Cosine similarity** measures exactly that: `1` means the same direction, `0` means unrelated. The question is about food, so its vector is something like `[0.0, 0.05, 0.95, 0.15]`.

Without an index the database compares it against every memory. That is fine for nine and not fine for nine million.

```panel
{
  "type": "query",
  "id": "17fc3799a7639278e1944e3b",
  "state": {
    "queryState": {
      "doc": "-- \"What should I cook tonight?\" as a vector\nLET $question = [0.00, 0.05, 0.95, 0.15];\n\nSELECT\n    content,\n    vector::similarity::cosine(embedding, $question) AS similarity\nFROM memory\nORDER BY similarity DESC\nLIMIT 3;",
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

The two food memories come first, and neither contains the word "cook" in the form the question used. That is the whole point of recalling by meaning: the agent now knows to suggest something vegetarian without coriander.

---

## 5. Index it

An **HNSW index** finds the nearest vectors without visiting every row. It is approximate by design - it explores part of the space and returns the best it found - which is how vector search stays fast at scale. `DIST COSINE` tells it which notion of distance to use, and it matches the similarity you just computed by hand.

```panel
{
  "type": "query",
  "id": "094213472091aace56112e27",
  "state": {
    "queryState": {
      "doc": "DEFINE INDEX OVERWRITE memory_embedding ON memory\n    FIELDS embedding\n    HNSW DIMENSION 4 DIST COSINE TYPE F32;",
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

With the index in place, the `<|k, ef|>` operator asks for the `k` nearest neighbours. `ef` is how many candidates the index may explore on the way; higher is more accurate and a little slower. `vector::distance::knn()` returns the distance the index measured, where `0` is identical and `1` is unrelated.

```panel
{
  "type": "query",
  "id": "dcdb0de8a4eb610c2c43f487",
  "state": {
    "queryState": {
      "doc": "LET $question = [0.00, 0.05, 0.95, 0.15];\n\nSELECT content, vector::distance::knn() AS distance\nFROM memory\nWHERE embedding <|3, 40|> $question\nORDER BY distance;",
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
> Change the `3` to another number and run it again. `INFO FOR TABLE memory;` shows the index you just defined.

---

## 6. Recent and important first

Meaning alone is a poor memory. Ask *"Anything about Ada's family?"* and the closest match by meaning is the ninety-day-old fact that Fay lives in Madrid - true, but the agent should lead with the trip on Friday. A memory's worth is its relevance, times how fresh it is, times how much it mattered when it was formed.

Freshness here is `0.98` to the power of the memory's age in days, so a memory loses about half its weight every month. Compare the two orderings: by similarity alone, and by the combined score.

```panel
{
  "type": "query",
  "id": "81d6f3716e79a04f623c57d9",
  "state": {
    "queryState": {
      "doc": "-- \"Anything about Ada's family?\" as a vector\nLET $question = [0.00, 0.30, 0.00, 0.95];\n\nSELECT\n    content,\n    vector::similarity::cosine(embedding, $question) AS similarity,\n    math::pow(0.98, duration::days(time::now() - created)) AS freshness,\n    importance,\n    vector::similarity::cosine(embedding, $question)\n        * math::pow(0.98, duration::days(time::now() - created))\n        * importance AS score\nFROM memory\nWHERE embedding <|4, 40|> $question\nORDER BY score DESC;",
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

The trip is first now, the old fact about Fay is still there behind it, and the grey weather - barely relevant, barely important, and old - has sunk to the bottom, where it belongs.

---

## 7. The exact words still matter

Vectors are good at meaning and bad at names. Ask about "Bob" and a vector may blur him into everything about work. **Full-text search** covers that side, ranking matches with BM25 - the scoring most search engines use. An **analyzer** decides how text is cut into words: this one splits on spaces and punctuation, lowercases everything, and stems English words so "meeting" and "meetings" count as the same term.

```panel
{
  "type": "query",
  "id": "e8321773fb420aac374ea193",
  "state": {
    "queryState": {
      "doc": "DEFINE ANALYZER OVERWRITE english\n    TOKENIZERS blank, class, punct\n    FILTERS lowercase, snowball(english);\n\nDEFINE INDEX OVERWRITE memory_content_search ON memory\n    FIELDS content FULLTEXT ANALYZER english BM25;",
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

The `@0@` operator matches a field against search terms, and `search::score(0)` is the BM25 score of that match.

```panel
{
  "type": "query",
  "id": "e2e10a0ab5f2d63573ca5707",
  "state": {
    "queryState": {
      "doc": "SELECT content, search::score(0) AS score\nFROM memory\nWHERE content @0@ \"Bob\"\nORDER BY score DESC;",
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

The best recall does both and merges the results. **Reciprocal rank fusion** gives every memory a score from its *position* in each list, so one that ranks well by keyword *and* by meaning rises to the top. `search::rrf` does the merge: hand it the ranked lists, a smoothing constant (60 is the usual choice) and how many results you want back.

```panel
{
  "type": "query",
  "id": "3867f7cb6f6d0789cbf58db7",
  "state": {
    "queryState": {
      "doc": "-- \"Remind me about the Madrid trip\"\nLET $terms  = \"Madrid trip\";\nLET $vector = [0.05, 0.85, 0.05, 0.50];\n\n-- Arm one: the exact words, scored with BM25\nLET $by_keyword = (\n    SELECT id, content, search::score(0) AS score\n    FROM memory\n    WHERE content @0@ $terms\n    ORDER BY score DESC\n    LIMIT 5\n);\n\n-- Arm two: the meaning, scored by vector distance\nLET $by_meaning = (\n    SELECT id, content, vector::distance::knn() AS distance\n    FROM memory\n    WHERE embedding <|5, 40|> $vector\n    ORDER BY distance\n    LIMIT 5\n);\n\n-- Fused: one list, ranked by how well each memory did in both\nLET $fused = search::rrf([$by_keyword, $by_meaning], 60, 5);\n\nSELECT content, rrf_score AS score FROM $fused;",
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

## 8. Who and what a memory is about

Memories mention people, places and things, and an agent that knows *which* can answer questions no vector can: "tell me everything about Fay", or "who else comes up when Ada talks about work". Give those things records of their own and connect each memory to what it is about with an edge. `RELATE` creates the edge, and the arrows walk it.

```panel
{
  "type": "query",
  "id": "a62a31719e43695dbebdad8a",
  "state": {
    "queryState": {
      "doc": "DEFINE TABLE OVERWRITE entity SCHEMAFULL;\nDEFINE FIELD OVERWRITE name ON entity TYPE string;\nDEFINE FIELD OVERWRITE kind ON entity TYPE string;\n\nDEFINE TABLE OVERWRITE about TYPE RELATION FROM memory TO entity;\n\nINSERT INTO entity [\n    { id: entity:fay,       name: \"Fay\",       kind: \"person\" },\n    { id: entity:bob,       name: \"Bob\",       kind: \"person\" },\n    { id: entity:madrid,    name: \"Madrid\",    kind: \"place\" },\n    { id: entity:surrealdb, name: \"SurrealDB\", kind: \"organisation\" }\n];\n\nRELATE memory:sister->about->entity:fay;\nRELATE memory:sister->about->entity:madrid;\nRELATE memory:trip->about->entity:fay;\nRELATE memory:trip->about->entity:madrid;\nRELATE memory:bob_joining->about->entity:bob;\nRELATE memory:works_at->about->entity:surrealdb;\nRELATE memory:launch_demo->about->entity:surrealdb;\n\n-- Everything the agent knows about Fay, oldest first\nSELECT VALUE content FROM entity:fay<-about<-memory ORDER BY created;\n\n-- What each entity is connected to, through the memories they share\nSELECT name, array::distinct(<-about<-memory->about->entity.name) AS appears_with FROM entity;",
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

Studio can draw this. Every record in a result becomes a node and the edges between them are looked up and drawn, so this block's output is set to **Graph** - run it and drag the nodes around.

```panel
{
  "type": "query",
  "id": "0e0978f3ee2367eb0f51a235",
  "state": {
    "queryState": {
      "doc": "SELECT * FROM memory, entity;",
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
    "outputMode": "graph"
  }
}
```

---

## 9. Forget on purpose

A memory that never forgets is a memory that contradicts itself. Two things need doing regularly. When a fact changes, the old memory is marked **superseded** rather than deleted: it stays on record, and recall skips it. And episodic chatter that was never important and is now old is deleted outright - `RETURN BEFORE` shows what went.

```panel
{
  "type": "query",
  "id": "52e276fa70a04178feb630b4",
  "state": {
    "queryState": {
      "doc": "-- Ada changed her mind: the new fact is recorded, the old one is superseded\nCREATE memory:meetings_now CONTENT {\n    content: \"Ada now prefers afternoon meetings.\",\n    kind: \"semantic\",\n    importance: 0.6,\n    embedding: [0.85, 0.00, 0.00, 0.05]\n};\n\nUPDATE memory:meetings SET superseded = true;\n\n-- Old, unimportant and episodic: gone\nDELETE memory\nWHERE kind = \"episodic\" AND importance < 0.5 AND created < time::now() - 30d\nRETURN BEFORE;\n\nSELECT content, superseded, created FROM memory ORDER BY created;",
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

## 10. Wrap it in a function

Recall is one question the agent asks over and over, so keep the answer in the database as a **function**: every client asks the same way, and improving the scoring later changes nothing in the agent. This is the ranking from step 6 with the superseded memories filtered out, and `$limit` says how many to return.

```panel
{
  "type": "query",
  "id": "b1b913023290baf9bed41f7c",
  "state": {
    "queryState": {
      "doc": "DEFINE FUNCTION OVERWRITE fn::recall($vector: array<float>, $limit: int) {\n    RETURN SELECT\n        content,\n        kind,\n        created,\n        vector::similarity::cosine(embedding, $vector)\n            * math::pow(0.98, duration::days(time::now() - created))\n            * importance AS score\n    FROM memory\n    WHERE embedding <|10, 40|> $vector AND superseded = false\n    ORDER BY score DESC\n    LIMIT $limit;\n};\n\n-- \"How does Ada like to work?\"\nRETURN fn::recall([0.90, 0.00, 0.00, 0.05], 3);",
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

A language model wants its memories as text it can read, so shape the prompt in the database too. This is the *retrieval* half of retrieval-augmented generation: the agent embeds the question, the database returns what it remembers, and the model writes the reply with that in front of it.

```panel
{
  "type": "query",
  "id": "bd66e992d1760d5a18c9ed60",
  "state": {
    "queryState": {
      "doc": "LET $memories = fn::recall([0.90, 0.00, 0.00, 0.05], 3);\n\nRETURN {\n    system: \"You are Ada's assistant. What you remember about Ada:\\n- \" + array::join($memories.content, \"\\n- \"),\n    recalled: array::len($memories)\n};",
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

## 11. Give the agent a door

`DEFINE API` turns the function into a real endpoint, served by the database at `POST /api/<namespace>/<database>/recall`. No server in between: the agent sends a vector and receives its memories as JSON. `api::invoke` calls the route from inside SurrealQL, so you can try it right here.

```panel
{
  "type": "query",
  "id": "975a20605d0c3ee7fdec02ae",
  "state": {
    "queryState": {
      "doc": "DEFINE API OVERWRITE \"/recall\"\n    FOR post\n    MIDDLEWARE api::timeout(5s)\n    PERMISSIONS FULL\n    THEN {\n        LET $vector = $request.body.vector;\n\n        IF $vector = NONE {\n            RETURN {\n                status: 400,\n                body: { error: \"Send the question's embedding as 'vector'\" }\n            };\n        };\n\n        RETURN {\n            status: 200,\n            body: { memories: fn::recall($vector, $request.body.limit ?? 3) }\n        };\n    };\n\n-- Call it as the agent would\napi::invoke(\"/recall\", {\n    method: \"post\",\n    body: { vector: [0.00, 0.30, 0.00, 0.95], limit: 2 }\n});\n\n-- And without a vector\napi::invoke(\"/recall\", { method: \"post\", body: {} });",
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
> `PERMISSIONS FULL` makes the route public. Narrow it to an expression such as `$auth.id != NONE` to require a signed-in user - the **Surreal Start: Auth** guide shows how users sign in.

---

## 12. Real embeddings

Everything above works unchanged with real vectors. Change the `4` in the field and the index to your model's size - `1536` for OpenAI's `text-embedding-3-small`, for example - and let the agent compute the vectors. The database never calls a model; it only stores and compares what it is given.

The vector then arrives as a **parameter**. Open the **Parameters** tab of this block: it holds a `vector`, and the query refers to it as `$vector`. That is exactly how an SDK passes one in.

```panel
{
  "type": "query",
  "id": "4427397dca968d52051a993e",
  "state": {
    "queryState": {
      "doc": "-- The vector comes from the Parameters tab beside this query\nRETURN fn::recall($vector, 3);",
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
      "doc": "{\n    \"vector\": [\n        0.05,\n        0.85,\n        0.05,\n        0.5\n    ]\n}",
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

## 13. From your agent's code

Two calls cover most of what an agent does with its memory: write something it just learned, and recall what matters before it answers. `embed` stands for whichever embedding model you use.

<Tabs>
<TabItem label="JavaScript">

```javascript
import { Surreal } from "surrealdb";

const db = new Surreal();

await db.connect("wss://<your-instance>/rpc", {
    namespace: "<your-namespace>",
    database: "<your-database>",
});

await db.signin({ username: "<user>", password: "<password>" });

// Remember something the user just said
await db.create("memory", {
    content: "Ada is allergic to peanuts.",
    kind: "semantic",
    importance: 0.9,
    embedding: await embed("Ada is allergic to peanuts."),
});

// Recall before answering
const question = "What should I cook tonight?";
const [memories] = await db.query("RETURN fn::recall($vector, 3);", {
    vector: await embed(question),
});
```

</TabItem>
<TabItem label="Python">

```python
from surrealdb import Surreal

with Surreal("wss://<your-instance>/rpc") as db:
    db.signin({"username": "<user>", "password": "<password>"})
    db.use("<your-namespace>", "<your-database>")

    # Remember something the user just said
    db.create("memory", {
        "content": "Ada is allergic to peanuts.",
        "kind": "semantic",
        "importance": 0.9,
        "embedding": embed("Ada is allergic to peanuts."),
    })

    # Recall before answering
    question = "What should I cook tonight?"
    memories = db.query("RETURN fn::recall($vector, 3);", {"vector": embed(question)})
```

</TabItem>
</Tabs>

---

## 14. Clean up

Optional. This removes everything the guide created and leaves the database as it found it.

```panel
{
  "type": "query",
  "id": "e38253ca3d0b5fe9c6bc29c5",
  "state": {
    "queryState": {
      "doc": "REMOVE TABLE about;\nREMOVE TABLE entity;\nREMOVE TABLE memory;\nREMOVE FUNCTION fn::recall;\nREMOVE API \"/recall\";\nREMOVE ANALYZER english;",
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
- **The other guides**: *Fundamentals* covers the everyday statements this guide leaned on, *Graph* goes further with the edges from step 8, and *Auth* secures the door from step 11. All three are on your instance's dashboard under **Guides**.
- **SurrealDB University**: https://surrealdb.com/learn

You now have a database that remembers what an agent learns, recalls it by meaning, freshness, importance, exact words and relationships, forgets on purpose, and serves all of it through one call - which is what an agent's memory needs to be.
