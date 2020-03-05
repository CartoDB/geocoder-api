\set ECHO none
-- add the schema cdb_dataservices_server to the SEARCH_PATH
DO $$ BEGIN
    PERFORM set_config('search_path', current_setting('search_path')||', cdb_dataservices_server', false);
END $$;
\set ECHO all

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getdemographicsnapshot'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getsegmentsnapshot'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getmeasure'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getmeasurebyid'
              AND oidvectortypes(p.proargtypes)  = 'text, text, text, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getcategory'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getuscensusmeasure'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getuscensuscategory'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getpopulation'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_search'
              AND oidvectortypes(p.proargtypes)  = 'text, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getavailableboundaries'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getboundary'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getboundaryid'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getboundarybyid'
              AND oidvectortypes(p.proargtypes)  = 'text, text, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getmeta'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, json, integer, integer, integer');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getdata'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geomval[], json, boolean');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getdata'
              AND oidvectortypes(p.proargtypes)  = 'text, text, text[], json');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getboundariesbygeometry'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getboundariesbypointandradius'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, numeric, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getpointsbygeometry'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getpointsbypointandradius'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, numeric, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getavailablenumerators'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text[], text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getavailabledenominators'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text[], text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getavailablegeometries'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text[], text, text, text, integer');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_getavailabletimespans'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text[], text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_legacybuildermetadata'
              AND oidvectortypes(p.proargtypes)  = 'text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'obs_metadatavalidation'
              AND oidvectortypes(p.proargtypes)  = 'text, text, geometry, text, json, integer');
