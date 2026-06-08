-- ATC Frequencies — Play Store Metrics Schema
-- Run once after play-store-schema.sql
-- psql "$NEON_DATABASE_URL" -f play-store-schema.sql

-- Daily install / uninstall / active device counts per country
CREATE TABLE IF NOT EXISTS ps_installs (
  date                    DATE         NOT NULL,
  country                 VARCHAR(10)  NOT NULL,
  daily_device_installs   INT          NOT NULL DEFAULT 0,
  daily_device_uninstalls INT          NOT NULL DEFAULT 0,
  daily_device_upgrades   INT          NOT NULL DEFAULT 0,
  total_user_installs     BIGINT       NOT NULL DEFAULT 0,
  daily_user_installs     INT          NOT NULL DEFAULT 0,
  daily_user_uninstalls   INT          NOT NULL DEFAULT 0,
  active_device_installs  BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (date, country)
);

-- Daily ratings per country
CREATE TABLE IF NOT EXISTS ps_ratings (
  date                  DATE          NOT NULL,
  country               VARCHAR(10)   NOT NULL,
  daily_average_rating  NUMERIC(4,2)  NOT NULL DEFAULT 0,
  total_average_rating  NUMERIC(4,2)  NOT NULL DEFAULT 0,
  PRIMARY KEY (date, country)
);

-- Daily store listing performance per country
CREATE TABLE IF NOT EXISTS ps_store_performance (
  date                         DATE        NOT NULL,
  country                      VARCHAR(10) NOT NULL,
  store_listing_visitors       INT         NOT NULL DEFAULT 0,
  store_listing_acquisitions   INT         NOT NULL DEFAULT 0,
  PRIMARY KEY (date, country)
);

-- Tracks which GCS files have been synced — prevents double-importing
CREATE TABLE IF NOT EXISTS ps_sync_log (
  filename    TEXT         PRIMARY KEY,
  report_type TEXT         NOT NULL,
  row_count   INT          NOT NULL DEFAULT 0,
  synced_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Indexes for Grafana time-range queries
CREATE INDEX IF NOT EXISTS idx_ps_installs_date   ON ps_installs (date DESC);
CREATE INDEX IF NOT EXISTS idx_ps_ratings_date    ON ps_ratings (date DESC);
CREATE INDEX IF NOT EXISTS idx_ps_perf_date       ON ps_store_performance (date DESC);

SELECT 'Play Store tables ready' AS status;
