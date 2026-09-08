---
{
  "panels": {},
  "studio": "notebook/1"
}
---

# Surreal Start: Graph

You are still exploring, so this guide shows you the thing SurrealDB does that most databases cannot: it stores connections as data in their own right and lets you walk them. By the end you will have built a small social graph and asked it real questions - who knows whom, who to introduce to whom, how two strangers are connected - and seen the whole thing drawn, all in SurrealQL with no joins anywhere.

**How to read this guide.** Each numbered step explains one idea and then hands you a live query block. Press **Run Query** and look at what comes back before moving on. The steps build on each other, so take them in order. Everything is written into four small tables that the last step removes again.

> [!tip]
> The words on this page are fixed, but the queries are not. Every block is a real query panel: change a name, add a hop, run it again and see what happens.

> [!important]
> This guide needs SurrealDB 3.x and a connection to a namespace and database you can write to. It creates the tables `person`, `topic`, `knows` and `likes`, and touches nothing else.

---

## 1. Check where you are

A SurrealDB server holds **namespaces**, a namespace holds **databases**, and a database holds **tables** of **records**. Studio has already chosen a namespace and a database for this connection; `session::ns()` and `session::db()` tell you which.

```panel
{
  "type": "query",
  "id": "f94d859e802e29a3ee570801",
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

## 2. Records are the nodes

A graph is records and the connections between them. The records are ordinary: here six people and three topics. `INSERT` writes several at once, and a table comes into being the moment something is written to it.

```panel
{
  "type": "query",
  "id": "557f7dd00233945f246c7c76",
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

## 3. Edges are records too

An **edge** connects two records and is a record itself, stored in its own table with an `in` and an `out`. Because it is a record it can carry fields - `since`, here - and can be queried like any other table. `RELATE` creates one.

Defining the edge table as a `RELATION` is optional, but `FROM person TO person` says what it may connect, and SurrealDB refuses anything else.

```panel
{
  "type": "query",
  "id": "66dee756c306a37d4ea110d3",
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

## 4. See it

Before asking the graph anything, look at it. Studio can draw a result as a graph: every record in the result becomes a node, and the edges between those records are looked up and drawn. This block's output is already set to **Graph** - run it, then drag the nodes around and use the legend to hide a table or an edge. Any query panel can do the same from its results toolbar.

```panel
{
  "type": "query",
  "id": "1dc6e5dd56896b9b1d5c6e84",
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

Keep the picture in mind: every query from here on is a question about it.

---

## 5. Walk the graph

The arrows follow edges. `->knows->person` walks *out* of a record along `knows` edges to the people at the other end, and `<-knows<-person` walks *in*, to the people whose edges point here. Put `.name` on the end to read a field off everything you reached.

```panel
{
  "type": "query",
  "id": "bd3ed1a1b2d540597ec56154",
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

## 6. Data on the edges

An edge's fields are right there in the walk. A `WHERE` inside the arrows filters the edges you follow, and selecting from the edge table itself reads them as rows - `in.name` reaches through to the record the edge starts from.

```panel
{
  "type": "query",
  "id": "c4f8929cb7d77333fe4d318b",
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

## 7. More than one hop

Chain the arrows to go further: `->knows->person->knows->person` is friends of friends. `array::distinct` folds out the duplicates, since two friends may share one.

Chains get long, so SurrealQL has a **recursive** form. `@.{2}(->knows->person)` walks the path in the brackets exactly twice; `@.{1..3}` collects everything between one and three hops away. A walk can reach the same person along two routes, so `array::distinct` tidies the lists.

```panel
{
  "type": "query",
  "id": "3a5f5cdfbceb1421dd5f9441",
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
  "id": "ee162c3354e52497acc84e03",
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

## 8. Recommend someone

Friends of friends you do not know yet is the classic recommendation, and it is one query. `array::complement` takes the people two hops out and removes the people one hop out - and Ada herself.

A graph also connects through what people *like*. Walk to Ada's topics and back out again to everyone else who likes them.

```panel
{
  "type": "query",
  "id": "c4ee4b93118916847d3ce951",
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

## 9. The shortest path

How does Ada reach Fay? `+shortest=person:fay` asks the recursion to stop at Fay and return the way there; `+inclusive` puts Ada at the start of it.

```panel
{
  "type": "query",
  "id": "af4ee6404d01224e87c826f6",
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

## 10. Count and rank

An arrow walk is an array, so `count()` counts it. Who is known by the most people, and which topic has the most fans?

```panel
{
  "type": "query",
  "id": "07862e465dd50cea8ef66e8e",
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

## 11. Change the graph

Edges are records, so `DELETE` on a walk removes exactly the edges it reaches. Deleting a record removes every edge touching it as well, so the graph never holds an edge to nothing.

```panel
{
  "type": "query",
  "id": "871fa24e87eb51e16815a8cc",
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

Optional. This removes everything the guide created and leaves the database as it found it.

```panel
{
  "type": "query",
  "id": "674dae6d1e5e6a2191791bbe",
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
- **The other guides**: *Fundamentals* covers the everyday statements this guide skipped past, and *Auth* and *AI* each build something on top of them. All three are on your instance's dashboard under **Guides**.
- **SurrealDB University**: https://surrealdb.com/learn

You now have a database that stores records, connects them with edges you can read, filter and count, and answers questions about the shape of the graph in one statement - which is what a graph database is for.
