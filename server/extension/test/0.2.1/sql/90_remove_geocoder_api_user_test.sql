REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA cdb_geocoder_server FROM geocoder_api;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM geocoder_api;
REVOKE USAGE ON SCHEMA cdb_geocoder_server FROM geocoder_api;
REVOKE USAGE ON SCHEMA public FROM geocoder_api;
REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM geocoder_api;