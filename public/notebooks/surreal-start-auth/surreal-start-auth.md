---
{
  "panels": {},
  "studio": "notebook/1"
}
---

# Surreal Start: Auth

This guide turns a database into a backend. By the end you will have a `user` table people can sign up to and sign in to, passwords that are hashed before they are stored, permissions that let a signed-in user see only what is theirs, a check that runs on every request, a read-only account for reporting and a way in for tokens issued elsewhere - all defined inside SurrealDB, in SurrealQL, with no application server in between.

**How to read this guide.** Each numbered step explains one idea and then hands you a live query block. Press **Run Query** and look at what comes back before moving on. The steps build on each other, so take them in order. Everything is written into two small tables, two access methods and one user that the last step removes again.

> [!tip]
> The words on this page are fixed, but the queries are not. Every block is a real query panel: change a rule, try a different password, run it again and see what happens.

> [!important]
> This guide needs SurrealDB 3.x and a connection to a namespace and database you can write to. It creates the tables `user` and `post`, the access methods `account` and `sso` and the user `reporting`, and touches nothing else.

---

## 1. Check who you are

SurrealDB has two kinds of identity. **System users** are administrators: defined by you, given a role, allowed to define things. **Record users** are rows in a table of your own - your application's users - and SurrealDB can sign them up, sign them in and decide record by record what each of them may see.

`$session` describes the connection this guide runs on: the namespace and database it is using, and how it authenticated. Studio signs in as a system user, which is why the steps below are allowed to define tables and access methods.

```panel
{
  "type": "query",
  "id": "6f059a205a9783191217777d",
  "state": {
    "queryState": {
      "doc": "RETURN {\n    namespace: session::ns(),\n    database: session::db(),\n    session: $session\n};",
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

## 2. A table for users

Start with the table your users will live in. `PERMISSIONS` is where the deciding happens: `$auth` is the signed-in user's own record, so `WHERE id = $auth.id` means "only your own row". Creating is `NONE`, because sign-up will do that, and a unique index makes sure an email is used once.

```panel
{
  "type": "query",
  "id": "7d9a48d790bbfc14062b6cf2",
  "state": {
    "queryState": {
      "doc": "DEFINE TABLE OVERWRITE user SCHEMAFULL\n    PERMISSIONS\n        FOR select, update, delete WHERE id = $auth.id\n        FOR create NONE;\n\nDEFINE FIELD OVERWRITE name     ON user TYPE string;\nDEFINE FIELD OVERWRITE email    ON user TYPE string ASSERT string::is_email($value);\nDEFINE FIELD OVERWRITE password ON user TYPE string;\nDEFINE FIELD OVERWRITE enabled  ON user TYPE bool DEFAULT true;\n\nDEFINE INDEX OVERWRITE user_email ON user FIELDS email UNIQUE;",
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

## 3. Sign-up and sign-in, defined

An **access method** says how someone becomes a record user. `SIGNUP` runs when a new user registers: it receives whatever the client sent as parameters - here `$name`, `$email` and `$password` - and creates the record. `SIGNIN` runs when they come back: it finds the record whose password matches, and a match is a successful sign-in. Both return a token the client sends with every request after.

Passwords are never stored as typed. `crypto::argon2::generate` hashes one on the way in, and `crypto::argon2::compare` checks a hash against a password on the way back.

```panel
{
  "type": "query",
  "id": "64e106565159cce2f0a00de2",
  "state": {
    "queryState": {
      "doc": "DEFINE ACCESS OVERWRITE account ON DATABASE TYPE RECORD\n    SIGNUP (\n        CREATE user CONTENT {\n            name:     $name,\n            email:    $email,\n            password: crypto::argon2::generate($password)\n        }\n    )\n    SIGNIN (\n        SELECT * FROM user\n        WHERE email = $email\n        AND crypto::argon2::compare(password, $password)\n    )\n    DURATION FOR TOKEN 15m, FOR SESSION 12h;",
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

`DURATION` sets how long the token stays valid and how long a session opened with it lasts. A short token and a longer session is the usual pair: the token is what leaks, the session is what the user feels.

---

## 4. What a hash is

Run the two functions the access method uses. The hash changes every time you run this - it is salted - yet it still matches the password it was made from, and only that one.

```panel
{
  "type": "query",
  "id": "9674970ae2f712106253e47c",
  "state": {
    "queryState": {
      "doc": "LET $hash = crypto::argon2::generate(\"correct horse battery staple\");\n\nRETURN {\n    hash: $hash,\n    right_password: crypto::argon2::compare($hash, \"correct horse battery staple\"),\n    wrong_password: crypto::argon2::compare($hash, \"Tr0ub4dor&3\")\n};",
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

## 5. Some users

Sign-up is something a client does over the wire, so to have users to work with, create two the way `SIGNUP` would. The system user this guide runs as is not subject to the table's permissions, which is what makes this possible from here.

Look at what is stored: the password column holds a hash, and the email index refuses a second Ada.

```panel
{
  "type": "query",
  "id": "40bcd5a6877c165e558d7cc4",
  "state": {
    "queryState": {
      "doc": "INSERT INTO user [\n    {\n        id: user:ada,\n        name: \"Ada\",\n        email: \"ada@example.com\",\n        password: crypto::argon2::generate(\"ada-pass\")\n    },\n    {\n        id: user:bob,\n        name: \"Bob\",\n        email: \"bob@example.com\",\n        password: crypto::argon2::generate(\"bob-pass\")\n    }\n];\n\nSELECT id, name, email, password FROM user;\n\n-- fails on purpose: the email is already taken\nCREATE user SET name = \"Ada again\", email = \"ada@example.com\", password = \"x\";",
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

## 6. Permissions, row by row

Now something for users to own. A `post` belongs to its author and is a draft until published. Its `PERMISSIONS` say who sees what: anyone signed in sees published posts and their own drafts, only the author changes or deletes one, and only a signed-in user creates one at all. `READONLY` on `created` stops it being edited after the fact.

```panel
{
  "type": "query",
  "id": "85feba83bebac234afc8a30a",
  "state": {
    "queryState": {
      "doc": "DEFINE TABLE OVERWRITE post SCHEMAFULL\n    PERMISSIONS\n        FOR select WHERE published = true OR author = $auth.id\n        FOR create WHERE $auth.id != NONE\n        FOR update, delete WHERE author = $auth.id;\n\nDEFINE FIELD OVERWRITE title     ON post TYPE string;\nDEFINE FIELD OVERWRITE body      ON post TYPE string;\nDEFINE FIELD OVERWRITE author    ON post TYPE record<user>;\nDEFINE FIELD OVERWRITE published ON post TYPE bool DEFAULT false;\nDEFINE FIELD OVERWRITE created   ON post TYPE datetime DEFAULT time::now() READONLY;\n\nINSERT INTO post [\n    { id: post:hello, title: \"Hello, world\",          body: \"First!\",                author: user:ada, published: true },\n    { id: post:draft, title: \"Half-written thoughts\", body: \"To be continued.\",      author: user:ada, published: false },\n    { id: post:rust,  title: \"Why Rust\",              body: \"Fearless concurrency.\", author: user:bob, published: true }\n];",
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

Permissions apply to record users, and this guide runs as a system user, so the first query below sees every post. The other two apply the `select` permission's own condition by hand, which is exactly what SurrealDB does for a session signed in as Ada or as Bob: Ada sees her draft, Bob does not.

```panel
{
  "type": "query",
  "id": "f83a551959649e0f72f7a1a5",
  "state": {
    "queryState": {
      "doc": "-- A system user sees everything\nSELECT title, author.name AS author, published FROM post;\n\n-- What a session signed in as Ada sees\nSELECT title, published FROM post WHERE published = true OR author = user:ada;\n\n-- What a session signed in as Bob sees\nSELECT title, published FROM post WHERE published = true OR author = user:bob;",
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
> You can run a block as a record user for real. In a block's results toolbar, the query panel shows which user its queries run as - the connection's own, by default. Switch it to **Record user**, choose the `account` access method and enter Ada's email and password, and `SELECT title FROM post` returns only what Ada may see, with no `WHERE` written by you.

---

## 7. Sign in from an application

The access method is used from a client, not from a query. The SDKs wrap it, and the HTTP endpoints take the same parameters. Both return the token, and every request that carries it runs as that user, with the permissions above applied to it.

<Tabs>
<TabItem label="JavaScript">

```javascript
import { Surreal } from "surrealdb";

const db = new Surreal();

await db.connect("wss://<your-instance>/rpc", {
    namespace: "<your-namespace>",
    database: "<your-database>",
});

// Runs the SIGNUP query with these parameters and keeps the token
await db.signup({
    access: "account",
    variables: { name: "Ada", email: "ada@example.com", password: "ada-pass" },
});

// From here on, this connection is Ada: only her own row and posts are visible
const posts = await db.query("SELECT title FROM post");
```

</TabItem>
<TabItem label="HTTP">

```bash
curl -X POST https://<your-instance>/signin \
    -H "Accept: application/json" \
    -d '{ "NS": "<your-namespace>", "DB": "<your-database>", "AC": "account", "email": "ada@example.com", "password": "ada-pass" }'
```

</TabItem>
</Tabs>

---

## 8. A check on every request

`AUTHENTICATE` runs whenever a token for this access method is used - at sign-up, at sign-in and on every request after. It is the place for checks that must hold every time rather than once: here, that the account is still enabled. `THROW` refuses the request; `RETURN $auth` lets it through.

Disable Bob, and his next request is turned away even though his password is still right.

```panel
{
  "type": "query",
  "id": "50790baffc4f907b5befbf3f",
  "state": {
    "queryState": {
      "doc": "DEFINE ACCESS OVERWRITE account ON DATABASE TYPE RECORD\n    SIGNUP (\n        CREATE user CONTENT {\n            name:     $name,\n            email:    $email,\n            password: crypto::argon2::generate($password)\n        }\n    )\n    SIGNIN (\n        SELECT * FROM user\n        WHERE email = $email\n        AND crypto::argon2::compare(password, $password)\n    )\n    AUTHENTICATE {\n        IF !$auth.enabled {\n            THROW \"This account has been disabled\";\n        };\n        RETURN $auth;\n    }\n    DURATION FOR TOKEN 15m, FOR SESSION 12h;\n\nUPDATE user:bob SET enabled = false;\n\nSELECT name, enabled FROM user;",
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

## 9. System users and roles

Administrators are **system users**, defined with a role: `OWNER` may do anything, `EDITOR` may change data but not users or access, `VIEWER` may only read. A user can be scoped to the whole server, a namespace or one database. This one is a read-only account for a reporting tool, scoped to this database.

`INFO FOR DB` lists everything defined here - the tables, the access method and the user, with the password already hashed.

```panel
{
  "type": "query",
  "id": "be0f7d2f75c3e81b6fbe9db0",
  "state": {
    "queryState": {
      "doc": "DEFINE USER OVERWRITE reporting ON DATABASE\n    PASSWORD \"replace-this-with-a-long-random-password\"\n    ROLES VIEWER\n    DURATION FOR TOKEN 15m, FOR SESSION 8h;\n\nINFO FOR DB;",
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

## 10. Tokens from elsewhere

Users often already have an identity - a company login, a social account. `WITH JWT` lets an access method accept tokens issued by that provider instead of minting its own: the token is verified with the provider's key, and `AUTHENTICATE` maps its claims onto a `user` record. `$token` holds the claims, so a match on the email claim is enough to become that user.

```panel
{
  "type": "query",
  "id": "58318989e54beb47871f59c0",
  "state": {
    "queryState": {
      "doc": "DEFINE ACCESS OVERWRITE sso ON DATABASE TYPE RECORD\n    WITH JWT ALGORITHM HS512 KEY \"replace-this-with-the-secret-your-identity-provider-signs-tokens-with\"\n    AUTHENTICATE {\n        IF $auth.id {\n            RETURN $auth.id;\n        } ELSE IF $token.email {\n            RETURN SELECT VALUE id FROM ONLY user WHERE email = $token.email LIMIT 1;\n        };\n    }\n    DURATION FOR SESSION 1h;",
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
> For OAuth and OpenID Connect providers, `URL "https://.../.well-known/jwks.json"` in place of `KEY` fetches the provider's public keys and follows their rotation.

---

## 11. Manage it from here

Everything this guide defined is also managed from Studio's **Authentication** panel, which lists the system users and access methods of the connected database. This is that panel, embedded and already showing the access methods on this database - `account` and `sso` should both be there.

```panel
{
  "type": "authentication",
  "id": "4f805dd7ba88a3ca0f31af13",
  "state": {
    "level": "database",
    "scope": "access"
  }
}
```

---

## 12. Clean up

Optional. This removes everything the guide created and leaves the database as it found it.

```panel
{
  "type": "query",
  "id": "e29bcf438a98f9e37b351664",
  "state": {
    "queryState": {
      "doc": "REMOVE TABLE post;\nREMOVE TABLE user;\nREMOVE ACCESS account ON DATABASE;\nREMOVE ACCESS sso ON DATABASE;\nREMOVE USER reporting ON DATABASE;",
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

- **Authentication**: https://surrealdb.com/docs/surrealdb/security/authentication
- **DEFINE ACCESS**: https://surrealdb.com/docs/surrealql/statements/define/access
- **Permissions**: https://surrealdb.com/docs/surrealql/statements/define/table#defining-permissions
- **More auth queries**: apply the *Surreal Start* dataset from the Datasets page and open its *Authentication* sample.
- **The other guides**: *Fundamentals*, *Graph* and *AI* are on your instance's dashboard under **Guides**.
- **SurrealDB University**: https://surrealdb.com/learn

You now have a database that signs users up and in, stores their passwords safely, shows each of them only their own data and accepts identities from elsewhere - which is most of what an application needs from a backend.
