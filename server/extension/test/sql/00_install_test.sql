-- Only show warning or error messages in the tests output
\set QUIET on
SET client_min_messages TO WARNING;

-- Install the extension
CREATE EXTENSION cdb_dataservices_server CASCADE;
\unset QUIET

-- Mock the redis server connection to point to this very test db
SELECT cartodb.cdb_conf_setconf('redis_metrics_config', '{"redis_host": "localhost", "redis_port": 6379, "timeout": 0.1, "redis_db": 5}');
SELECT cartodb.cdb_conf_setconf('redis_metadata_config', '{"redis_host": "localhost", "redis_port": 6379, "timeout": 0.1, "redis_db": 5}');
SELECT cartodb.cdb_conf_setconf('heremaps_conf', '{"geocoder": {"app_id": "dummy_id", "app_code": "dummy_code", "geocoder_cost_per_hit": 1}, "isolines": {"app_id": "dummy_id", "app_code": "dummy_code"}}');
SELECT cartodb.cdb_conf_setconf('mapzen_conf', '{"routing": {"api_key": "routing_dummy_api_key", "monthly_quota": 1500000}, "geocoder": {"api_key": "geocoder_dummy_api_key", "monthly_quota": 1500000}, "matrix": {"api_key": "matrix_dummy_api_key", "monthly_quota": 1500000}}');
SELECT cartodb.cdb_conf_setconf('mapbox_conf', '{"routing": {"api_keys": ["routing_dummy_api_key"], "monthly_quota": 1500000}, "geocoder": {"api_keys": ["geocoder_dummy_api_key"], "monthly_quota": 1500000}, "matrix": {"api_keys": ["matrix_dummy_api_key"], "monthly_quota": 1500000}}');
SELECT cartodb.cdb_conf_setconf('tomtom_conf', '{"routing": {"api_keys": ["routing_dummy_api_key"], "monthly_quota": 1500000}, "geocoder": {"api_keys": ["geocoder_dummy_api_key"], "monthly_quota": 1500000}, "isolines": {"api_keys": ["isolines_dummy_api_key"], "monthly_quota": 1500000}}');
SELECT cartodb.cdb_conf_setconf('geocodio_conf', '{"geocoder": {"api_keys": ["geocoder_dummy_api_key"], "monthly_quota": 1500000}}');
SELECT cartodb.cdb_conf_setconf('logger_conf', '{"geocoder_log_path": "/dev/null"}');

-- Mock the varnish invalidation function
-- (used by cdb_geocoder tests)
CREATE OR REPLACE FUNCTION public.cdb_invalidate_varnish(table_name text) RETURNS void AS $$
BEGIN
  RETURN;
END
$$
LANGUAGE plpgsql;

-- Set user quota
SELECT cartodb.CDB_SetUserQuotaInBytes(0);
