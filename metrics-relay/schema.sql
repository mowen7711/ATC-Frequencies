-- ATC Frequencies — Metrics Schema
-- Run once against your NeonDB database
-- psql "your-neon-connection-string" -f schema.sql

CREATE TABLE IF NOT EXISTS atc_metrics (
  id          BIGSERIAL    PRIMARY KEY,
  ts          TIMESTAMPTZ  NOT NULL,
  measurement TEXT         NOT NULL,
  install_id  TEXT         NOT NULL,
  tags        JSONB        NOT NULL DEFAULT '{}',
  fields      JSONB        NOT NULL DEFAULT '{}'
);

-- Time-range scans (used by every Grafana query)
CREATE INDEX IF NOT EXISTS idx_atc_ts
  ON atc_metrics (ts DESC);

-- Measurement + time (most common filter pattern)
CREATE INDEX IF NOT EXISTS idx_atc_measurement_ts
  ON atc_metrics (measurement, ts DESC);

-- Per-install queries (session history, unique install counts)
CREATE INDEX IF NOT EXISTS idx_atc_install_ts
  ON atc_metrics (install_id, ts DESC);

-- Tag filtering — airport ICAO, event type, feature name, etc.
CREATE INDEX IF NOT EXISTS idx_atc_tags
  ON atc_metrics USING GIN (tags);

-- Field range queries — duration_ms, bytes, etc.
CREATE INDEX IF NOT EXISTS idx_atc_fields
  ON atc_metrics USING GIN (fields);

-- Confirm
SELECT 'atc_metrics table ready' AS status;
