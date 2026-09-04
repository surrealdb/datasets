---
{
  "panels": {},
  "studio": "notebook/1"
}
---

# Surreal Start: Fundamentals

You are about to learn the everyday SurrealQL: the handful of statements that create, read, change and connect records, and the schema that keeps them honest. By the end you will have a small team directory with people, the companies they work for and who knows whom - built, queried, aggregated and cleaned up again, all in SurrealQL.

Every query lives in a block below. Read the words above it, press **Run Query**, and look at what comes back before moving on. The blocks build on each other, so run them in order. Everything is written into three small tables that the last block removes again.

> [!tip]
> Press the `</>` button in the top right to see the markdown behind this document, and press it again to come back. Every block is plain JSON, so you can copy one, change the query and make the notebook your own.

> [!important]
> This notebook needs SurrealDB 3.x, and a connection to a namespace and database you can write to. Nothing here touches tables you already have.

---

## 1. Say hello

Make sure the connection works and see where you are. `session::ns()` and `session::db()` answer with the namespace and database this notebook is talking to, and `RETURN` hands back any value you give it.

```panel
{
  "type": "query",
  "id": "756536452d0d501d2e71b93c",
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

## 2. Create some records

A **record** lives in a table and has an id. `person:ada` is the record `ada` in the table `person` - you pick the id, or leave it off and SurrealDB generates one. The table does not have to exist first: writing to it creates it, and until you give it a schema it accepts any fields you like.

`CONTENT` takes a whole object. Notice the values: a string, a number, an array and a date, all stored as what they are rather than as text.

```panel
{
  "type": "query",
  "id": "d817c2d7b2463f69b4be73ed",
  "state": {
    "queryState": {
      "doc": "CREATE person:ada CONTENT {\n    name: \"Ada\",\n    age: 36,\n    skills: [\"maths\", \"engines\"],\n    joined: d'2024-02-01T09:00:00Z'\n};\n\nCREATE person:bob CONTENT {\n    name: \"Bob\",\n    age: 29,\n    skills: [\"rust\"],\n    joined: d'2024-05-20T09:00:00Z'\n};\n\nCREATE person:cleo CONTENT {\n    name: \"Cleo\",\n    age: 41,\n    skills: [\"design\", \"rust\"],\n    joined: d'2023-11-11T09:00:00Z'\n};",
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

## 3. Read them back

`SELECT` reads records. It looks like SQL and mostly behaves like it: pick fields, filter with `WHERE`, sort with `ORDER BY`. Two things are new. `SELECT * FROM ONLY person:ada` reads one record and returns it on its own rather than in a list, and a field can be reached into - `skills[0]` is the first skill, and `CONTAINS` asks whether an array holds a value.

```panel
{
  "type": "query",
  "id": "7f0f803508c02f37fd48d119",
  "state": {
    "queryState": {
      "doc": "SELECT * FROM person;\n\nSELECT name, age FROM person WHERE age > 30 ORDER BY age DESC;\n\nSELECT * FROM ONLY person:ada;\n\nSELECT name, skills[0] AS first_skill, array::len(skills) AS skill_count FROM person;\n\nSELECT name FROM person WHERE skills CONTAINS \"rust\";",
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

You do not have to write a query to look at a table. This is the **Explorer**, the same panel you reach from the sidebar, pointed at `person`. Click a record to inspect it.

```panel
{
  "type": "explorer",
  "id": "5b6a2d9c1e7f4a3b8c0d2e1f",
  "state": {
    "table": "person"
  }
}
```

---

## 4. Change them

`UPDATE` changes a record that exists. `SET` assigns fields, and `+=` appends to an array or adds to a number. `MERGE` folds an object into the record, adding the fields it names and leaving the rest alone. `UPSERT` is an `UPDATE` that creates the record when it is not there, which is what you want for "make sure this exists".

```panel
{
  "type": "query",
  "id": "cfa34e2a71032abc0b661448",
  "state": {
    "queryState": {
      "doc": "UPDATE person:ada SET age += 1, skills += \"surrealql\";\n\nUPDATE person:bob MERGE { city: \"Rotterdam\" };\n\nUPSERT person:dan SET name = \"Dan\", age = 25, skills = [\"support\"];\n\nSELECT * FROM person ORDER BY name;",
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

## 5. Link records to each other

A field can hold a **record id**, and a query can follow it. Give everyone a company and read the company's fields straight through the link with `works_at.name` - no join to write. `FETCH` swaps the id for the whole record instead.

The other direction works too. `$parent` is the record being selected, so a subquery on `company` can ask which people point at it.

```panel
{
  "type": "query",
  "id": "44960e55beb889aa16db116c",
  "state": {
    "queryState": {
      "doc": "CREATE company:surrealdb SET name = \"SurrealDB\", city = \"London\";\nCREATE company:acme SET name = \"Acme\", city = \"Berlin\";\n\nUPDATE person:ada, person:bob SET works_at = company:surrealdb;\nUPDATE person:cleo, person:dan SET works_at = company:acme;\n\nSELECT name, works_at.name AS company, works_at.city AS city FROM person;\n\nSELECT * FROM person:ada FETCH works_at;\n\nSELECT name, (SELECT VALUE name FROM person WHERE works_at = $parent.id) AS staff FROM company;",
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

## 6. Connect them with edges

A link lives on one record and points one way. An **edge** is a record of its own that connects two others, so it can carry data - when the connection was made, how strong it is - and can be walked from either end. `RELATE` creates one, and the arrows follow them: `->knows->person` walks out from a person, `<-knows<-person` walks back in.

```panel
{
  "type": "query",
  "id": "788b5588206df0ae287233e9",
  "state": {
    "queryState": {
      "doc": "RELATE person:ada->knows->person:bob SET since = d'2022-06-01';\nRELATE person:ada->knows->person:cleo SET since = d'2023-01-15';\nRELATE person:bob->knows->person:dan SET since = d'2024-06-01';\n\nSELECT name, ->knows->person.name AS knows FROM person;\n\nSELECT name, <-knows<-person.name AS known_by FROM person:dan;",
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
> Edges are where SurrealDB becomes a graph database. The *Surreal Start: Graph* notebook goes much further with them.

---

## 7. Add a schema

So far the table has taken whatever it was given. `SCHEMAFULL` turns that around: only the fields you define are allowed, each with a type. `ASSERT` adds a rule a value must pass, `DEFAULT` fills a field that was not given, and `option<...>` marks one that may be missing. The records you already have stay as they are; the rules apply to every write from now on.

```panel
{
  "type": "query",
  "id": "0e64a3a719e47d6a815099dc",
  "state": {
    "queryState": {
      "doc": "DEFINE TABLE OVERWRITE person SCHEMAFULL;\n\nDEFINE FIELD OVERWRITE name     ON person TYPE string;\nDEFINE FIELD OVERWRITE age      ON person TYPE int ASSERT $value >= 0;\nDEFINE FIELD OVERWRITE skills   ON person TYPE array<string> DEFAULT [];\nDEFINE FIELD OVERWRITE joined   ON person TYPE datetime DEFAULT time::now();\nDEFINE FIELD OVERWRITE city     ON person TYPE option<string>;\nDEFINE FIELD OVERWRITE works_at ON person TYPE option<record<company>>;\n\nSELECT * FROM person ORDER BY name;",
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

Now watch the schema do its job. Both of these are refused - the first for a negative age, the second for a field the table does not know - and the error says exactly why.

```panel
{
  "type": "query",
  "id": "080e1945f76f6c833a040cf2",
  "state": {
    "queryState": {
      "doc": "-- fails on purpose: the age fails its ASSERT\nCREATE person:eve SET name = \"Eve\", age = -3;\n\n-- fails on purpose: `nickname` is not a defined field\nUPDATE person:ada SET nickname = \"Countess\";",
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

## 8. Count and group

`GROUP ALL` collapses a table into one row of totals, and `GROUP BY` collapses it into one row per value. The aggregate functions do the rest: `count()`, `math::mean`, `math::max`, and `array::group`, which gathers the arrays of everyone in the group. Any function can be chained onto a value with a dot, so `.flatten().distinct()` turns those into one list of distinct skills.

```panel
{
  "type": "query",
  "id": "67899b3f3cebefeca490f76c",
  "state": {
    "queryState": {
      "doc": "SELECT\n    count() AS people,\n    math::mean(age) AS average_age,\n    math::max(age) AS oldest\nFROM person GROUP ALL;\n\nSELECT\n    works_at.name AS company,\n    count() AS staff,\n    array::group(skills).flatten().distinct() AS skills\nFROM person GROUP BY company;",
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

## 9. Put logic in the database

A **function** wraps a query so every client asks the same way, and an **event** runs a query whenever a table changes. Here the event writes a `log` record each time a person is created, and creating Eve - with a valid age this time - triggers it.

```panel
{
  "type": "query",
  "id": "a355c5efc855220a2bff287c",
  "state": {
    "queryState": {
      "doc": "DEFINE FUNCTION OVERWRITE fn::greet($who: record<person>) {\n    RETURN \"Hello, \" + $who.name + \"!\";\n};\n\nRETURN fn::greet(person:ada);\n\nDEFINE EVENT OVERWRITE on_join ON person WHEN $event = \"CREATE\" THEN {\n    CREATE log SET message = \"Welcome \" + $after.name, at = time::now();\n};\n\nCREATE person:eve SET name = \"Eve\", age = 33;\n\nSELECT * FROM log;",
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

## 10. Clean up

Optional. This removes everything the notebook created and leaves the database as it found it. Removing a table takes its fields, events and records with it.

```panel
{
  "type": "query",
  "id": "88b882652cf32ade8b4f1958",
  "state": {
    "queryState": {
      "doc": "REMOVE TABLE knows;\nREMOVE TABLE person;\nREMOVE TABLE company;\nREMOVE TABLE log;\nREMOVE FUNCTION fn::greet;",
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

- **SurrealQL**: https://surrealdb.com/docs/surrealql
- **Schema and fields**: https://surrealdb.com/docs/surrealql/statements/define/field
- **A bigger example**: load the *Surreal Deal Store* dataset from the Datasets page - twelve tables of a real store, with sample queries.
- **The other notebooks**: *Surreal Start: Graph*, *Surreal Start: Auth* and *Surreal Start: AI* each take one of these ideas much further.
- **SurrealDB University**: https://surrealdb.com/learn/fundamentals

You now know how records are created, read, changed, linked and kept in shape - which is most of what any application asks of a database.
