---
{
  "panels": {},
  "studio": "notebook/1"
}
---

# Surreal Start: Fundamentals

You chose a database, so this guide is about using SurrealDB as one: putting records in, getting them back out, changing them, connecting them, and keeping all of it honest with a schema, indexes and transactions. By the end you will have a small team directory - people, the companies they work for and who knows whom - built, queried and cleaned up again, all in SurrealQL.

**How to read this guide.** Each numbered step explains one idea and then hands you a live query block. Press **Run Query** and look at what comes back before moving on. The steps build on each other, so take them in order. Everything is written into four small tables that the last step removes again.

> [!tip]
> The words on this page are fixed, but the queries are not. Every block is a real query panel: change a value, add a statement, run it again and see what happens.

> [!important]
> This guide needs SurrealDB 4.x and a connection to a namespace and database you can write to. It creates the tables `person`, `company`, `knows` and `log`, and touches nothing else.

---

## 1. Check where you are

A SurrealDB server holds **namespaces**, a namespace holds **databases**, and a database holds **tables** of **records**. Studio has already chosen a namespace and a database for this connection. `session::ns()` and `session::db()` tell you which, and `RETURN` hands back any value you give it.

```panel
{
  "type": "query",
  "id": "851986c40242273643ccb1be",
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

## 2. Create records

A **record** lives in a table and has an id. `person:ada` is the record `ada` in the table `person`. You choose the id, or leave it off and SurrealDB generates one. The table does not have to exist first - writing to it creates it - and until you give it a schema it accepts whatever fields you send.

`CONTENT` takes a whole object. Look at the values: strings, a number, an array and a date, each stored as what it is rather than as text.

```panel
{
  "type": "query",
  "id": "8d13f2123292f9970e6b75de",
  "state": {
    "queryState": {
      "doc": "CREATE person:ada CONTENT {\n    name: \"Ada\",\n    email: \"ada@example.com\",\n    age: 36,\n    skills: [\"maths\", \"engines\"],\n    joined: d'2024-02-01T09:00:00Z'\n};\n\nCREATE person:bob CONTENT {\n    name: \"Bob\",\n    email: \"bob@example.com\",\n    age: 29,\n    skills: [\"rust\"],\n    joined: d'2024-05-20T09:00:00Z'\n};\n\nCREATE person:cleo CONTENT {\n    name: \"Cleo\",\n    email: \"cleo@example.com\",\n    age: 41,\n    skills: [\"design\", \"rust\"],\n    joined: d'2023-11-11T09:00:00Z'\n};\n\n-- No id given, so SurrealDB generates one\nCREATE person SET name = \"Guest\", age = 50, skills = [];",
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

`SELECT` reads records. It looks like SQL and mostly behaves like it: choose fields, filter with `WHERE`, sort with `ORDER BY`, page with `LIMIT` and `START`. Three things are new. `ONLY` returns a single record on its own rather than in a list, a value can be reached into - `skills[0]` is the first skill - and `CONTAINS` asks whether an array holds a value.

Notice that every query here that returns more than one record says `ORDER BY`. SurrealDB 4.x can split a scan into parts that run at the same time, so without `ORDER BY` records come back in no particular order, and a `LIMIT` returns *some* of them rather than the first ones. Whenever order matters, ask for it.

```panel
{
  "type": "query",
  "id": "edce270dd33aab7c20c3a44e",
  "state": {
    "queryState": {
      "doc": "SELECT * FROM person ORDER BY name;\n\nSELECT name, age FROM person WHERE age > 30 ORDER BY age DESC;\n\nSELECT * FROM ONLY person:ada;\n\nSELECT name, skills[0] AS first_skill, array::len(skills) AS skill_count FROM person ORDER BY name;\n\nSELECT name FROM person WHERE skills CONTAINS \"rust\" ORDER BY name;\n\nSELECT VALUE name FROM person ORDER BY name LIMIT 2 START 1;",
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

You do not have to write a query to look at a table. This is Studio's **Explorer**, the same panel you reach from the sidebar, pointed at `person`. Click a record to inspect it.

```panel
{
  "type": "explorer",
  "id": "5f697ee3e6ed4ef5232f029b",
  "state": {
    "table": "person"
  }
}
```

---

## 4. Change and delete

`UPDATE` changes a record that exists. `SET` assigns fields, and `+=` appends to an array or adds to a number. `MERGE` folds an object into the record, adding the fields it names and leaving the rest alone. `UPSERT` is an `UPDATE` that creates the record when it is missing - the statement for "make sure this exists". `DELETE` removes records, and `RETURN BEFORE` shows you what went.

```panel
{
  "type": "query",
  "id": "3cadc6e5f6d0c3e32030754e",
  "state": {
    "queryState": {
      "doc": "UPDATE person:ada SET age += 1, skills += \"surrealql\";\n\nUPDATE person:bob MERGE { city: \"Rotterdam\" };\n\nUPSERT person:dan SET name = \"Dan\", email = \"dan@example.com\", age = 25, skills = [\"support\"], joined = time::now();\n\nDELETE person WHERE name = \"Guest\" RETURN BEFORE;\n\nSELECT * FROM person ORDER BY name;",
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

## 5. Link records

A field can hold another record's id, and a query can follow it. Give everyone a company, then read the company's fields straight through the link with `works_at.name` - there is no join to write. `FETCH` swaps the id for the whole record instead.

The other direction works too. Inside a subquery, `$parent` is the record being selected, so a query on `company` can ask which people point at it.

```panel
{
  "type": "query",
  "id": "40253723b00a5e88a87a628d",
  "state": {
    "queryState": {
      "doc": "CREATE company:surrealdb SET name = \"SurrealDB\", city = \"London\";\nCREATE company:acme SET name = \"Acme\", city = \"Berlin\";\n\nUPDATE person:ada, person:bob SET works_at = company:surrealdb;\nUPDATE person:cleo, person:dan SET works_at = company:acme;\n\nSELECT name, works_at.name AS company, works_at.city AS city FROM person ORDER BY name;\n\nSELECT * FROM person:ada FETCH works_at;\n\nSELECT name, (SELECT VALUE name FROM person WHERE works_at = $parent.id ORDER BY name) AS staff FROM company ORDER BY name;",
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

## 6. Connect records with edges

A link lives on one record and points one way. An **edge** is a record of its own that connects two others, so it can carry data - when the connection was made, how strong it is - and can be walked from either end. `RELATE` creates one, and the arrows follow them: `->knows->person` walks out from a person, `<-knows<-person` walks back in.

```panel
{
  "type": "query",
  "id": "6e65be5c2f36f25ac5ba54b2",
  "state": {
    "queryState": {
      "doc": "RELATE person:ada->knows->person:bob SET since = d'2022-06-01';\nRELATE person:ada->knows->person:cleo SET since = d'2023-01-15';\nRELATE person:bob->knows->person:dan SET since = d'2024-06-01';\n\nSELECT name, ->knows->person.name AS knows FROM person ORDER BY name;\n\nSELECT name, <-knows<-person.name AS known_by FROM person:dan;",
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
> Edges are where SurrealDB becomes a graph database. The **Surreal Start: Graph** guide is about nothing else.

---

## 7. Add a schema

So far `person` has taken whatever it was given. `SCHEMAFULL` turns that around: only the fields you define are allowed, each with a type. `ASSERT` adds a rule a value must pass, `DEFAULT` fills in a field that was not given, and `option<...>` marks one that may be missing.

`person` already holds records, and in a database created by SurrealDB 4.x a schema has to describe them too, not only what is written next. A new field whose type does not accept a missing value - `TYPE string`, say - is refused on a table that has records, until the statement says what those records hold. That is what `MIGRATE EXISTING ROWS` does: `USING $value` keeps the value a record already has, `FALLBACK` is what a record gets when it has none or its value does not fit, and `AS` names the migration so running this block again does not run it twice. The optional fields need no migration, because a missing value is already allowed.

```panel
{
  "type": "query",
  "id": "b0ad304b1071ca734ed18ec8",
  "state": {
    "queryState": {
      "doc": "DEFINE TABLE OVERWRITE person SCHEMAFULL;\n\nDEFINE FIELD OVERWRITE name ON person TYPE string\n    MIGRATE EXISTING ROWS AS person_name USING $value FALLBACK \"Unknown\";\nDEFINE FIELD OVERWRITE email ON person TYPE string ASSERT string::is_email($value)\n    MIGRATE EXISTING ROWS AS person_email USING $value FALLBACK \"unknown@example.com\";\nDEFINE FIELD OVERWRITE age ON person TYPE int ASSERT $value >= 0\n    MIGRATE EXISTING ROWS AS person_age USING $value FALLBACK 0;\nDEFINE FIELD OVERWRITE skills ON person TYPE array<string> DEFAULT []\n    MIGRATE EXISTING ROWS AS person_skills USING $value FALLBACK [];\nDEFINE FIELD OVERWRITE joined ON person TYPE datetime DEFAULT time::now()\n    MIGRATE EXISTING ROWS AS person_joined USING $value FALLBACK d'2024-01-01T00:00:00Z';\n\nDEFINE FIELD OVERWRITE city     ON person TYPE option<string>;\nDEFINE FIELD OVERWRITE works_at ON person TYPE option<record<company>>;\n\nSELECT * FROM person ORDER BY name;",
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

Every record already had a valid value, so nothing changed. `INFO FOR TABLE person` lists the fields and, under `migrations`, the migrations the table has run.

Now watch the schema do its job. Both of these are refused - the first for a negative age, the second for a field the table does not know - and each error says exactly why.

```panel
{
  "type": "query",
  "id": "9cc0b41fbdce763d784e1c7b",
  "state": {
    "queryState": {
      "doc": "-- fails on purpose: the age fails its ASSERT\nCREATE person:eve SET name = \"Eve\", email = \"eve@example.com\", age = -3;\n\n-- fails on purpose: `nickname` is not a defined field\nUPDATE person:ada SET nickname = \"Countess\";",
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

## 8. Index what you search by

Without an index, a `WHERE` reads every record in the table. `DEFINE INDEX` builds one on a field, and queries that filter on that field use it without being told to. `UNIQUE` adds a promise on top: no two records share a value. `EXPLAIN` at the end of a query shows the plan SurrealDB chose - look for an `IndexScan` naming the index.

```panel
{
  "type": "query",
  "id": "876967588bc7b22360726e44",
  "state": {
    "queryState": {
      "doc": "DEFINE INDEX OVERWRITE person_name  ON person FIELDS name;\nDEFINE INDEX OVERWRITE person_email ON person FIELDS email UNIQUE;\n\nSELECT * FROM person WHERE name = \"Ada\" EXPLAIN;\n\n-- fails on purpose: that email is already Ada's\nUPDATE person:bob SET email = \"ada@example.com\";",
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

## 9. Count and group

`GROUP ALL` collapses a table into one row of totals, and `GROUP BY` into one row per value. The aggregate functions do the rest: `count()`, `math::mean`, `math::max`, and `array::group`, which gathers the arrays of everyone in the group into one list of the distinct values they hold.

```panel
{
  "type": "query",
  "id": "f2f72434cf3a26c88ad00591",
  "state": {
    "queryState": {
      "doc": "SELECT\n    count() AS people,\n    math::mean(age) AS average_age,\n    math::max(age) AS oldest\nFROM person GROUP ALL;\n\nSELECT\n    works_at.name AS company,\n    count() AS staff,\n    array::group(skills) AS skills\nFROM person GROUP BY company ORDER BY company;",
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

## 10. Change several things at once

Some changes only make sense together. Dan moving companies is one write and recording that it happened is another, and neither should land without the other. A **transaction** makes a group of statements succeed or fail as one: `BEGIN` opens it, `COMMIT` applies everything inside, and an error anywhere - or a `CANCEL` - throws all of it away.

```panel
{
  "type": "query",
  "id": "593fd75127bb5b67ae99267c",
  "state": {
    "queryState": {
      "doc": "BEGIN TRANSACTION;\n\nUPDATE person:dan SET works_at = company:surrealdb;\nCREATE log SET message = \"Dan moved to SurrealDB\", at = time::now();\n\nCOMMIT TRANSACTION;\n\nSELECT name, works_at.name AS company FROM person:dan;\nSELECT * FROM log ORDER BY at;",
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

## 11. Put logic in the database

A **function** wraps a query so every client asks the same way, and an **event** runs a query whenever a table changes. Here the event writes a `log` record each time a person is created, and creating Eve - with a valid age this time - triggers it.

```panel
{
  "type": "query",
  "id": "089b3d5e213d58d167c6873a",
  "state": {
    "queryState": {
      "doc": "DEFINE FUNCTION OVERWRITE fn::greet($who: record<person>) {\n    RETURN \"Hello, \" + $who.name + \"!\";\n};\n\nRETURN fn::greet(person:ada);\n\nDEFINE EVENT OVERWRITE on_join ON person WHEN $event = \"CREATE\" THEN {\n    CREATE log SET message = \"Welcome \" + $after.name, at = time::now();\n};\n\nCREATE person:eve SET name = \"Eve\", email = \"eve@example.com\", age = 33;\n\nSELECT * FROM log ORDER BY at;",
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

## 12. Use it from your application

Everything above works the same from code: connect, choose a namespace and database, send SurrealQL. The SDKs speak the language this guide is written in, so a query that works here works there. Use an SDK release that supports SurrealDB 4.x - for JavaScript, version 2.1 or later.

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

const people = await db.query("SELECT name, works_at.name AS company FROM person ORDER BY name");
```

</TabItem>
<TabItem label="Python">

```python
from surrealdb import Surreal

with Surreal("wss://<your-instance>/rpc") as db:
    db.signin({"username": "<user>", "password": "<password>"})
    db.use("<your-namespace>", "<your-database>")

    people = db.query("SELECT name, works_at.name AS company FROM person ORDER BY name")
```

</TabItem>
<TabItem label="HTTP">

```bash
curl -X POST https://<your-instance>/sql \
    -u "<user>:<password>" \
    -H "surreal-ns: <your-namespace>" \
    -H "surreal-db: <your-database>" \
    -H "Accept: application/json" \
    --data-binary 'SELECT name, works_at.name AS company FROM person ORDER BY name;'
```

</TabItem>
</Tabs>

---

## 13. Clean up

Optional. This removes everything the guide created and leaves the database as it found it. Removing a table takes its fields, indexes, events, migrations and records with it.

```panel
{
  "type": "query",
  "id": "cb21825a4bae12e7ac089eb2",
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

- **SurrealQL reference**: https://surrealdb.com/docs/reference/query-language
- **Schema and fields**: https://surrealdb.com/docs/reference/query-language/statements/define/field
- **Migrating existing records**: https://surrealdb.com/docs/reference/query-language/statements/define/field#migrating-existing-records
- **Indexes**: https://surrealdb.com/docs/reference/query-language/statements/define/indexes
- **Transactions**: https://surrealdb.com/docs/learn/querying/concepts-and-guides/transactions
- **SDKs**: https://surrealdb.com/docs/reference/javascript and https://surrealdb.com/docs/reference/python
- **Coming from 3.x**: https://surrealdb.com/docs/operate/upgrading/3x-to-4x
- **A bigger example**: load the *Surreal Deal Store* dataset from the Datasets page - twelve tables of a real store, with sample queries.
- **The other guides**: *Graph*, *Auth* and *AI* are on your instance's dashboard under **Guides**. Each takes one idea from here much further.
- **SurrealDB University**: https://surrealdb.com/learn/fundamentals

You now know how records are created, read, changed, linked, indexed and kept in shape - which is most of what any application asks of a database.
