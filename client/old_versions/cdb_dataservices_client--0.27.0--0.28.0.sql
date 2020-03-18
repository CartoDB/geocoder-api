--DO NOT MODIFY THIS FILE, IT IS GENERATED AUTOMATICALLY FROM SOURCES
-- Complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION cdb_dataservices_client UPDATE TO '0.28.0'" to load this file. \quit

-- Make sure we have a sane search path to create/update the extension
SET search_path = "$user",cartodb,public,cdb_dataservices_client;

-- HERE goes your code to upgrade/downgrade

CREATE OR REPLACE FUNCTION cdb_dataservices_client._cdb_geocodio_geocode_street_point_exception_safe (searchtext text ,city text DEFAULT NULL ,state_province text DEFAULT NULL ,country text DEFAULT NULL)
RETURNS public.Geometry AS $$
DECLARE
  ret public.Geometry;
  username text;
  orgname text;
  _returned_sqlstate TEXT;
  _message_text TEXT;
  _pg_exception_context TEXT;
  apikey_permissions json;
BEGIN
  
  SELECT u, o, p INTO username, orgname, apikey_permissions FROM cdb_dataservices_client._cdb_entity_config() AS (u text, o text, p json);
  IF apikey_permissions IS NULL OR NOT apikey_permissions::jsonb ? 'geocoding' THEN
    RAISE EXCEPTION 'Geocoding permission denied';
  END IF;
  
  -- JSON value stored "" is taken as literal
  IF username IS NULL OR username = '' OR username = '""' THEN
    RAISE EXCEPTION 'Username is a mandatory argument, check it out';
  END IF;


  BEGIN
    SELECT cdb_dataservices_client._cdb_geocodio_geocode_street_point(username, orgname, searchtext, city, state_province, country) INTO ret; RETURN ret;
  EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS _returned_sqlstate = RETURNED_SQLSTATE,
                                _message_text = MESSAGE_TEXT,
                                _pg_exception_context = PG_EXCEPTION_CONTEXT;
        RAISE WARNING USING ERRCODE = _returned_sqlstate, MESSAGE = _message_text, DETAIL = _pg_exception_context;
         RETURN ret;
  END;
END;
$$  LANGUAGE 'plpgsql' SECURITY DEFINER STABLE PARALLEL UNSAFE
    SET search_path = pg_temp;

DROP FUNCTION IF EXISTS cdb_dataservices_client._cdb_geocodio_geocode_street_point (username text, orgname text, searchtext text, city text, state_province text, country text);
CREATE OR REPLACE FUNCTION cdb_dataservices_client._cdb_geocodio_geocode_street_point (username text, orgname text, searchtext text, city text DEFAULT NULL, state_province text DEFAULT NULL, country text DEFAULT NULL)
RETURNS Geometry AS $$
  CONNECT cdb_dataservices_client._server_conn_str();
  
  SELECT cdb_dataservices_server.cdb_geocodio_geocode_street_point (username, orgname, searchtext, city, state_province, country);

$$ LANGUAGE plproxy VOLATILE PARALLEL UNSAFE;

DROP FUNCTION IF EXISTS cdb_dataservices_client.cdb_geocodio_geocode_street_point (searchtext text ,city text ,state_province text ,country text);
CREATE OR REPLACE FUNCTION cdb_dataservices_client.cdb_geocodio_geocode_street_point (searchtext text ,city text DEFAULT NULL ,state_province text DEFAULT NULL ,country text DEFAULT NULL)
RETURNS public.Geometry AS $$
DECLARE
  ret public.Geometry;
  username text;
  orgname text;
  apikey_permissions json;
BEGIN
  
  SELECT u, o, p INTO username, orgname, apikey_permissions FROM cdb_dataservices_client._cdb_entity_config() AS (u text, o text, p json);
  IF apikey_permissions IS NULL OR NOT apikey_permissions::jsonb ? 'geocoding' THEN
    RAISE EXCEPTION 'Geocoding permission denied' USING ERRCODE = '01007';
  END IF;
  
  -- JSON value stored "" is taken as literal
  IF username IS NULL OR username = '' OR username = '""' THEN
    RAISE EXCEPTION 'Username is a mandatory argument, check it out';
  END IF;

  SELECT cdb_dataservices_client._cdb_geocodio_geocode_street_point(username, orgname, searchtext, city, state_province, country) INTO ret; RETURN ret;
END;
$$  LANGUAGE 'plpgsql' SECURITY DEFINER STABLE PARALLEL UNSAFE
    SET search_path = pg_temp;

GRANT EXECUTE ON FUNCTION cdb_dataservices_client.cdb_geocodio_geocode_street_point(searchtext text, city text, state_province text, country text) TO publicuser;
GRANT EXECUTE ON FUNCTION cdb_dataservices_client._cdb_geocodio_geocode_street_point_exception_safe(searchtext text, city text, state_province text, country text )  TO publicuser;

