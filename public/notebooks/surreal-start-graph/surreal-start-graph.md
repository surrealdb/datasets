---
{
  "panels": {},
  "studio": "notebook/1"
}
---

# Surreal Start: Graph

You are about to build a small social graph and walk it. By the end you will have people connected by edges that carry data, queries that follow those edges in both directions and several hops out, recursive queries that return a tree, a recommendation, a shortest path and a picture of the whole thing - all inside SurrealDB, in SurrealQL, with no joins anywhere.

Every query lives in a block below. Read the words above it, press **Run Query**, and look at what comes back before moving on. The blocks build on each other, so run them in order. Everything is written into four small tables that the last block removes again.

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
  "id": "348aa865f5686cefde6dffe1",
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

## 2. Nodes

A graph is records and the connections between them. The records are ordinary: here six people and three topics. `INSERT` writes several at once.

```panel
{
  "type": "query",
  "id": "cdfe57c6eb6e5adf32c8b198",
  "state": {
    "queryState": {
      "doc": "INSERT INTO person [\n    { id: person:ada,  name: \"Ada\",  city: \"London\" },\n    { id: person:bob,  name: \"Bob\",  city: \"Berlin\" },\n    { id: person:cleo, name: \"Cleo\", city: \"London\" },\n    { id: person:dan,  name: \"Dan\",  city: \"Paris\" },\n    { id: person:eve,  name: \"Eve\",  city: \"Berlin\" },\n    { id: person:fay,  name: \"Fay\",  city: \"Madrid\" }\n];\n\nINSERT INTO topic [\n    { id: topic:graphs, name: \"Graph databases\" },\n    { id: topic:rust,   name: \"Rust\" },\n    { id: topic:ai,     name: \"AI\" }\n];",
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

## 3. Edges

An **edge** connects two records and is a record itself, stored in its own table with an `in` and an `out`. Because it is a record it can carry fields - `since`, here - and can be queried like any other table. `RELATE` creates one.

Defining the edge table as a `RELATION` is optional, but `FROM person TO person` says what it may connect, and SurrealDB refuses anything else.

```panel
{
  "type": "query",
  "id": "a65e3d64923dece9fdb357f0",
  "state": {
    "queryState": {
      "doc": "DEFINE TABLE OVERWRITE knows TYPE RELATION FROM person TO person;\nDEFINE TABLE OVERWRITE likes TYPE RELATION FROM person TO topic;\n\nRELATE person:ada->knows->person:bob   SET since = d'2021-03-01';\nRELATE person:ada->knows->person:cleo  SET since = d'2019-08-15';\nRELATE person:cleo->knows->person:ada  SET since = d'2019-08-15';\nRELATE person:bob->knows->person:dan   SET since = d'2022-01-10';\nRELATE person:cleo->knows->person:dan  SET since = d'2023-05-05';\nRELATE person:dan->knows->person:eve   SET since = d'2020-11-30';\nRELATE person:eve->knows->person:fay   SET since = d'2024-02-14';\n\nRELATE person:ada->likes->topic:graphs;\nRELATE person:bob->likes->topic:rust;\nRELATE person:cleo->likes->topic:graphs;\nRELATE person:dan->likes->topic:ai;\nRELATE person:eve->likes->topic:graphs;\nRELATE person:fay->likes->topic:rust;\n\nSELECT * FROM knows;",
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

## 4. Walk the graph

The arrows follow edges. `->knows->person` walks *out* of a record along `knows` edges to the people at the other end, and `<-knows<-person` walks *in*, to the people whose edges point here. Put `.name` on the end to read a field off everything you reached.

```panel
{
  "type": "query",
  "id": "52e7820cfe62384bd8fcea2e",
  "state": {
    "queryState": {
      "doc": "SELECT name, ->knows->person.name AS knows FROM person;\n\nSELECT name, <-knows<-person.name AS known_by FROM person;",
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

Ada knows Bob and Cleo; Cleo knows Ada back. The graph is directed, and both directions are there to be read - `<->knows<->person` walks them both at once.

---

## 5. Data on the edges

An edge's fields are right there in the walk. A `WHERE` inside the arrows filters the edges you follow, and selecting from the edge table itself reads them as rows - `in.name` reaches through to the record the edge starts from.

```panel
{
  "type": "query",
  "id": "9b7f93757f130bf571059dcd",
  "state": {
    "queryState": {
      "doc": "SELECT name, ->knows[WHERE since < d'2021-01-01']->person.name AS old_friends FROM person;\n\nSELECT in.name AS from, out.name AS to, since FROM knows ORDER BY since;",
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

## 6. More than one hop

Chain the arrows to go further: `->knows->person->knows->person` is friends of friends. `array::distinct` folds out the duplicates, since two friends may share one.

Chains get long, so SurrealQL has a **recursive** form. `@.{2}(->knows->person)` walks the path in the brackets exactly twice; `@.{1..3}` collects everything between one and three hops away. A walk can reach the same person along two routes, so `array::distinct` tidies the lists.

```panel
{
  "type": "query",
  "id": "d20b98857e4d4c32621d8d3e",
  "state": {
    "queryState": {
      "doc": "SELECT name, array::distinct(->knows->person->knows->person.name) AS friends_of_friends\nFROM person:ada;\n\nSELECT\n    name,\n    array::distinct(@.{1}(->knows->person).name) AS one_hop,\n    array::distinct(@.{2}(->knows->person).name) AS two_hops,\n    array::distinct(@.{3}(->knows->person).name) AS three_hops\nFROM person:ada;",
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

The same form can build a **tree**. `.@` marks where the recursion continues, so each person carries the people they know, who carry the people they know, down to the depth you ask for.

```panel
{
  "type": "query",
  "id": "100da953a877d1bfafded28f",
  "state": {
    "queryState": {
      "doc": "SELECT @.{1..3}.{\n    name,\n    knows: ->knows->person.@\n} AS tree FROM person:ada;",
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

## 7. Recommend someone

Friends of friends that you do not know yet is the classic recommendation, and it is one query. `array::complement` takes the people two hops out and removes the people one hop out - and Ada herself.

A graph also connects through what people *like*. Walk to Ada's topics and back out again to everyone else who likes them.

```panel
{
  "type": "query",
  "id": "754cfc2f48c7ff84ca7419b3",
  "state": {
    "queryState": {
      "doc": "LET $me = person:ada;\nLET $friends = $me->knows->person;\n\n-- People two hops out that Ada does not know yet\nSELECT VALUE name FROM array::complement(\n    array::distinct($me->knows->person->knows->person),\n    $friends + [$me]\n);\n\n-- People who like what Ada likes\nSELECT VALUE name FROM $me->likes->topic<-likes<-person WHERE id != $me;",
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

## 8. The shortest path

How does Ada reach Fay? `+shortest=person:fay` asks the recursion to stop at Fay and return the way there; `+inclusive` puts Ada at the start of it.

```panel
{
  "type": "query",
  "id": "4f4c3912dc391d2ad4e4ee4a",
  "state": {
    "queryState": {
      "doc": "RETURN person:ada.{..+shortest=person:fay+inclusive}(->knows->person).name;",
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

## 9. Count and rank

An arrow walk is an array, so `count()` counts it. Who is known by the most people, and which topic has the most fans?

```panel
{
  "type": "query",
  "id": "07bcb1911e2ff943b890f3db",
  "state": {
    "queryState": {
      "doc": "SELECT\n    name,\n    count(<-knows<-person) AS known_by,\n    count(->knows->person) AS knows\nFROM person ORDER BY known_by DESC;\n\nSELECT name, count(<-likes<-person) AS fans FROM topic ORDER BY fans DESC;",
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

## 10. See it

Studio can draw a result as a graph: every record in it becomes a node, and the edges between those records are looked up and drawn. This block's output is set to **Graph** - run it, then drag the nodes around and use the legend to hide a table or an edge. Any query panel can do the same; the switch is in its results toolbar.

```panel
{
  "type": "query",
  "id": "d85453660a673a0c1356ffb5",
  "state": {
    "queryState": {
      "doc": "SELECT * FROM person, topic;",
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

## 11. Change the graph

Edges are records, so `DELETE` on a walk removes exactly the edges it reaches. Deleting a record removes every edge touching it as well, so the graph never holds an edge to nothing.

```panel
{
  "type": "query",
  "id": "122e2853e5e8144192a09459",
  "state": {
    "queryState": {
      "doc": "DELETE person:ada->knows WHERE out = person:bob;\n\nRELATE person:ada->knows->person:fay SET since = time::now();\n\nSELECT name, ->knows->person.name AS knows FROM person:ada;\n\nDELETE person:fay;\n\nSELECT count() FROM knows WHERE in = person:fay OR out = person:fay GROUP ALL;",
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

## 12. Clean up

Optional. This removes everything the notebook created and leaves the database as it found it.

```panel
{
  "type": "query",
  "id": "b038234d1f429ddfb4b38b9c",
  "state": {
    "queryState": {
      "doc": "REMOVE TABLE knows;\nREMOVE TABLE likes;\nREMOVE TABLE person;\nREMOVE TABLE topic;",
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

- **Graph queries**: https://surrealdb.com/docs/surrealdb/models/graph
- **RELATE**: https://surrealdb.com/docs/surrealql/statements/relate
- **Recursive paths**: https://surrealdb.com/docs/surrealql/datamodel/idioms#recursive-paths
- **A bigger graph**: load the *Surreal Deal Store* dataset from the Datasets page and try its *Graph relations* sample query.
- **SurrealDB University**: https://surrealdb.com/learn

You now have a database that stores records, connects them with edges you can read, filter and count, and answers questions about the shape of the graph in one statement - which is what a graph database is for.
