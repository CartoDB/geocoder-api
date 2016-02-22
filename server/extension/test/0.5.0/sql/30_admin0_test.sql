-- Check that the public function is callable, even with no data
-- It should return NULL
SELECT cdb_dataservices_server.cdb_geocode_admin0_polygon('test_user', 'test_orgname', 'Spain');

-- Insert some dummy synonym
INSERT INTO admin0_synonyms (name, adm0_a3) VALUES ('Spain', 'ESP');

-- Insert some dummy geometry to return
INSERT INTO ne_admin0_v3 (adm0_a3, the_geom) VALUES('ESP', ST_GeomFromText(
  'POLYGON((-71.1031880899493 42.3152774590236,
            -71.1031627617667 42.3152960829043,
            -71.102923838298 42.3149156848307,
            -71.1031880899493 42.3152774590236))',4326)
);

-- This should return the polygon inserted above
SELECT cdb_dataservices_server.cdb_geocode_admin0_polygon('test_user', 'test_orgname', 'Spain');

-- Check for admin0 signatures
SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'cdb_geocode_admin0_polygon'
              AND oidvectortypes(p.proargtypes)  = 'text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = '_cdb_geocode_admin0_polygon'
              AND oidvectortypes(p.proargtypes)  = 'text');
