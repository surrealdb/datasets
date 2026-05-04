-- ------------------------------------------------------------
-- Authentication in SurrealDB (v3)
--
-- SurrealDB provides two distinct authentication models:
--
--   1. System users  — defined with DEFINE USER, managed by admins,
--                      governed by Role-Based Access Control (RBAC).
--
--   2. Record users  — defined with DEFINE ACCESS, live as regular
--                      records in the database, support custom
--                      signup/signin logic and fine-grained permissions.
--
-- Learn more: https://surrealdb.com/docs/surrealdb/security/authentication
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 1. SYSTEM USERS
--
-- System users are created by administrators and assigned one of
-- three built-in roles:
--   OWNER  — full read/write access, including IAM resources
--   EDITOR — full read/write access, excluding IAM resources
--   VIEWER — read-only access
--
-- Users can be scoped to ROOT, a NAMESPACE, or a DATABASE.
-- ------------------------------------------------------------

-- Root-level user: has access to every namespace and database
DEFINE USER admin ON ROOT
    PASSWORD "VerySecurePassword!"
    ROLES OWNER;

-- Namespace-level user: scoped to a single namespace
USE NS myapp;
DEFINE USER ns_editor ON NAMESPACE
    PASSWORD "EditorPass123!"
    ROLES EDITOR
    -- Token expires in 5 min; authenticated session lasts 12 hours
    DURATION FOR TOKEN 5m, FOR SESSION 12h;

-- Database-level user: scoped to a single database
USE NS myapp DB production;
DEFINE USER db_viewer ON DATABASE
    PASSWORD "ViewerPass!"
    ROLES VIEWER
    DURATION FOR TOKEN 5m, FOR SESSION 8h;

-- Inspect all defined users at the current level
INFO FOR ROOT;
INFO FOR DB;


-- ------------------------------------------------------------
-- 2. RECORD ACCESS — Email & Password
--
-- Record users live as records in the database, enabling SurrealDB
-- to act as a Backend-as-a-Service (BaaS). You define custom
-- SIGNUP and SIGNIN logic using SurrealQL expressions.
-- ------------------------------------------------------------

-- Define a schemafull user table.
-- $auth points to the authenticated user's record at query time.
DEFINE TABLE user SCHEMAFULL
    PERMISSIONS
        -- Users can only read and modify their own record
        FOR select, update, delete WHERE id = $auth.id
        FOR create NONE; -- creation is handled through SIGNUP

DEFINE FIELD name     ON user TYPE string;
DEFINE FIELD email    ON user TYPE string
    ASSERT string::is_email($value);
DEFINE FIELD password ON user TYPE string;

-- Prevent duplicate accounts by enforcing a unique email index
DEFINE INDEX email_idx ON user FIELDS email UNIQUE;

-- Define the access method that powers signup and signin.
-- Variables passed by the client (e.g. $email, $password) are
-- available inside the SIGNUP and SIGNIN expressions.
DEFINE ACCESS account ON DATABASE TYPE RECORD
    SIGNUP (
        CREATE user CONTENT {
            name:     $name,
            email:    $email,
            password: crypto::argon2::generate($password)
        }
    )
    SIGNIN (
        SELECT * FROM user
        WHERE email    = $email
        AND   crypto::argon2::compare(password, $password)
    )
    -- Short-lived token; longer session so users stay logged in
    DURATION FOR TOKEN 15m, FOR SESSION 12h;


-- ------------------------------------------------------------
-- 3. RECORD ACCESS — AUTHENTICATE Clause
--
-- The AUTHENTICATE clause runs on every signin, signup, and
-- token-based authentication attempt. Use it to enforce checks
-- that should be validated at auth time rather than in every query.
-- ------------------------------------------------------------

DEFINE ACCESS account ON DATABASE TYPE RECORD
    SIGNUP (
        CREATE user CONTENT {
            name:     $name,
            email:    $email,
            password: crypto::argon2::generate($password),
            enabled:  true
        }
    )
    SIGNIN (
        SELECT * FROM user
        WHERE email    = $email
        AND   crypto::argon2::compare(password, $password)
    )
    AUTHENTICATE {
        -- Reject authentication for disabled accounts
        IF !$auth.enabled {
            THROW "This account has been disabled"
        };
        -- Returning $auth confirms the authenticated record identity
        RETURN $auth;
    }
    DURATION FOR TOKEN 15m, FOR SESSION 12h;


-- ------------------------------------------------------------
-- 4. TABLE & FIELD PERMISSIONS
--
-- Record users only access data that their PERMISSIONS clauses allow.
-- Key variables available in permission expressions:
--   $auth   — the authenticated user's record
--   $token  — claims from the JWT used to authenticate the session
--   $access — the name of the access method used
-- ------------------------------------------------------------

-- Example: blog posts with row-level visibility rules
DEFINE TABLE post SCHEMAFULL
    PERMISSIONS
        -- Anyone authenticated can read public posts or their own
        FOR select WHERE author = $auth.id OR public = true
        -- Only the author can create, modify, or delete their posts
        FOR create, update, delete WHERE author = $auth.id;

DEFINE FIELD title   ON post TYPE string;
DEFINE FIELD content ON post TYPE string;
-- Default author to the currently authenticated user
DEFINE FIELD author  ON post TYPE record<user> DEFAULT $auth.id;
DEFINE FIELD public  ON post TYPE bool DEFAULT false;

-- Example: an admin-only table that only privileged tokens can access
DEFINE TABLE audit_log SCHEMAFULL
    PERMISSIONS
        -- Allow access only when the token carries an admin claim
        FOR select WHERE $token.role = "admin"
        FOR create, update, delete NONE;

DEFINE FIELD event   ON audit_log TYPE string;
DEFINE FIELD created ON audit_log TYPE datetime DEFAULT time::now();


-- ------------------------------------------------------------
-- 5. JWT ACCESS — External Token Provider
--
-- Trust tokens issued by a third party (OAuth2, OIDC, Auth0, etc.).
-- DEFINE ACCESS TYPE JWT verifies incoming tokens with the provided
-- key or remote JWKS URL, and grants system-user-level access.
-- ------------------------------------------------------------

-- Symmetric HMAC algorithm (both sign and verify use the same secret)
DEFINE ACCESS jwt_hmac ON DATABASE TYPE JWT
    ALGORITHM HS512
    KEY "replace-with-a-long-random-secret"
    DURATION FOR SESSION 2h;

-- Asymmetric algorithm (verifier holds only the public key)
DEFINE ACCESS jwt_rs256 ON DATABASE TYPE JWT
    ALGORITHM RS256
    KEY "-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...your-public-key...
-----END PUBLIC KEY-----"
    DURATION FOR SESSION 1h;

-- JWKS endpoint — recommended for OAuth / OpenID Connect providers.
-- SurrealDB fetches the key set and rotates automatically.
DEFINE ACCESS oidc_provider ON DATABASE TYPE JWT
    URL "https://example.com/.well-known/jwks.json"
    AUTHENTICATE {
        -- Reject tokens from unexpected issuers
        IF $token.iss != "https://example.com" {
            THROW "Invalid token issuer"
        };
        -- Verify the audience claim contains our service identifier
        IF type::is::array($token.aud) {
            IF "my-service" NOT IN $token.aud {
                THROW "Invalid token audience"
            }
        } ELSE IF $token.aud != "my-service" {
            THROW "Invalid token audience"
        };
    }
    DURATION FOR SESSION 1h;


-- ------------------------------------------------------------
-- 6. RECORD ACCESS WITH EXTERNAL JWT (WITH JWT clause)
--
-- Combining TYPE RECORD with WITH JWT lets an external provider
-- issue tokens that still respect fine-grained PERMISSIONS clauses.
-- Use AUTHENTICATE to map the external identity to an internal record.
--
-- In v3, use type::record() (replaces type::thing() from v2).
-- ------------------------------------------------------------

DEFINE ACCESS external_auth ON DATABASE TYPE RECORD
    WITH JWT
        ALGORITHM HS512
        KEY "replace-with-a-long-random-secret"
    AUTHENTICATE {
        -- If a matching internal record was found, use it directly
        IF $auth.id {
            RETURN $auth.id;
        } ELSE IF $token.email {
            -- Otherwise, locate the user by the email claim in the token
            RETURN SELECT * FROM user WHERE email = $token.email;
        };
    };

-- The user table PERMISSIONS still apply to record users authenticated
-- via this method — giving you both external auth and row-level security
DEFINE TABLE user SCHEMAFULL
    PERMISSIONS
        FOR select, update WHERE id = $auth.id OR $token.privileged = true
        FOR delete             WHERE id = $auth.id
        FOR create             NONE;


-- ------------------------------------------------------------
-- 7. TOKEN AUDITING WITH AUTHENTICATE
--
-- Each token SurrealDB issues carries a unique `jti` (JWT ID) claim.
-- You can use AUTHENTICATE to log and selectively revoke tokens.
-- In v3, use type::record() to construct record IDs from token claims.
-- ------------------------------------------------------------

DEFINE ACCESS account ON DATABASE TYPE RECORD
    SIGNUP (
        CREATE user CONTENT {
            email:    $email,
            password: crypto::argon2::generate($pass)
        }
    )
    SIGNIN (
        SELECT * FROM user
        WHERE email = $email
        AND   crypto::argon2::compare(password, $pass)
    )
    AUTHENTICATE {
        -- Block tokens that have been explicitly revoked
        -- v3: type::record() replaces type::thing() from v2
        IF type::record("token", $token.jti).revoked = true {
            THROW "This token has been revoked"
        };
        -- Record the token on first use (INSERT ignores duplicates)
        INSERT INTO token {
            id:      $token.jti,
            exp:     $token.exp,
            revoked: false
        };
        -- Write an audit entry every time the token is used
        CREATE audit CONTENT { token: $token.jti, time: time::now() };
        RETURN $auth;
    }
    DURATION FOR TOKEN 30d, FOR SESSION 1h;


-- ------------------------------------------------------------
-- 8. SESSION INSPECTION
--
-- After authenticating, SurrealDB populates several read-only
-- parameters that can be queried to inspect the current session.
-- ------------------------------------------------------------

-- $session contains metadata about the current connection
SELECT * FROM $session;

-- $token contains the JWT claims used to establish the session
SELECT * FROM $token;

-- $auth points to the record of the authenticated record user
-- (NONE when authenticated as a system user)
SELECT * FROM $auth;

-- Practical use: check when the current session expires
SELECT exp FROM $session;

// To learn more about authentication in SurrealDB, visit:
// https://surrealdb.com/docs/surrealdb/security/authentication
