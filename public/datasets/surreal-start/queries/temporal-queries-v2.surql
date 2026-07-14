-- ------------------------------------------------------------
-- Temporal & time-series queries (v2)
--
-- Time-series workloads centre on timestamps, tags, and aggregations:
--
--   1. Ingestion          — composite record ids that encode time
--   2. Time buckets        — grouping raw readings into time windows
--   3. Materialized views  — precomputed, auto-updating aggregate tables
--   4. Retention           — DROP tables for high-throughput raw data
--
-- Learn more: https://surrealdb.com/docs/surrealdb/models/time-series
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 1. INGESTING MEASUREMENTS WITH COMPOSITE RECORD IDS
--
-- Encoding [location, timestamp] directly into the record id keeps
-- readings for a location physically sorted, so range queries over
-- time are cheap and need no secondary index.
-- ------------------------------------------------------------

CREATE sensor_readings:['greenhouse-1', d'2025-04-10T09:15:00Z']
    SET temperature_celsius = 21.4, humidity = 55;
CREATE sensor_readings:['greenhouse-1', d'2025-04-10T09:45:00Z']
    SET temperature_celsius = 21.9, humidity = 54;
CREATE sensor_readings:['greenhouse-1', d'2025-04-10T10:05:00Z']
    SET temperature_celsius = 22.3, humidity = 52;
CREATE sensor_readings:['greenhouse-2', d'2025-04-10T09:20:00Z']
    SET temperature_celsius = 19.8, humidity = 61;

-- Build the same id from parts — handy inside functions or events.
-- v2 uses type::thing(); v3 renames this to type::record() (see v3 dataset)
LET $id = type::thing("sensor_readings", ["greenhouse-1", d'2025-04-10T10:05:00Z']);
SELECT * FROM $id;

-- Range queries fall out naturally from the id structure — everything
-- for greenhouse-1 within a time window, no WHERE clause required
SELECT * FROM sensor_readings:['greenhouse-1', d'2025-04-10T09:00:00Z']..=['greenhouse-1', d'2025-04-10T10:00:00Z'];

-- A note on composite ids: 2.x treats t:[1], t:[1f] and t:[1dec] as three
-- distinct keys with their own sort position. 3.x unifies numeric equality
-- and ordering across int/float/decimal inside record ids (see the v3
-- dataset). Using datetime components, as above, sidesteps this entirely.


-- ------------------------------------------------------------
-- 2. TIME BUCKETS
--
-- time::floor() snaps each timestamp down to the start of a fixed
-- duration. Grouping by that bucket collapses raw readings into
-- per-window aggregates — the bread and butter of time-series queries.
-- ------------------------------------------------------------

SELECT
    id[0]                            AS location,
    time::floor(id[1], 1h)           AS hour_bucket,
    count()                          AS readings,
    math::mean(temperature_celsius)  AS avg_temp,
    math::mean(humidity)             AS avg_humidity
FROM sensor_readings
GROUP BY location, hour_bucket;

-- time::group() is a simpler alternative for calendar-aligned buckets
-- (whole minutes/hours/days/months/years) instead of fixed durations
SELECT
    id[0]                     AS location,
    time::group(id[1], "day") AS day_bucket,
    math::mean(temperature_celsius) AS avg_temp
FROM sensor_readings
GROUP BY location, day_bucket;


-- ------------------------------------------------------------
-- 3. MATERIALIZED VIEWS
--
-- DEFINE TABLE ... AS turns the query above into a table that stays
-- incrementally up to date as new readings arrive — no cron job and
-- no separate ETL step required.
-- ------------------------------------------------------------

DEFINE TABLE hourly_by_location AS
    SELECT
        id[0]                            AS location,
        time::floor(id[1], 1h)           AS hour_bucket,
        count()                          AS readings,
        math::mean(temperature_celsius)  AS avg_temp
    FROM sensor_readings
    GROUP BY location, hour_bucket;

SELECT * FROM hourly_by_location;

-- Stream new buckets to a dashboard in real time as they're written
LIVE SELECT * FROM hourly_by_location;


-- ------------------------------------------------------------
-- 4. RETENTION FOR HIGH-FREQUENCY DATA
--
-- A DROP table accepts writes (and still runs events or feeds views)
-- but never retains the raw row afterwards — ideal for high-frequency
-- ticks where only the aggregate matters in the end.
-- ------------------------------------------------------------

DEFINE TABLE raw_tick DROP;

CREATE raw_tick SET symbol = "SDB", price = 128.42, at = time::now();

-- The write succeeded, but nothing is kept in `raw_tick` itself
SELECT * FROM raw_tick;

// To learn more about time-series modelling in SurrealDB, visit:
// https://surrealdb.com/docs/surrealdb/models/time-series
