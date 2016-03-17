-- Check that the public function is callable, even with no data
-- It should return NULL
SELECT cdb_dataservices_server.cdb_geocode_namedplace_point('test_user', 'test_orgname', 'Elx');
SELECT cdb_dataservices_server.cdb_geocode_namedplace_point('test_user', 'test_orgname', 'Elx', 'Spain');
SELECT cdb_dataservices_server.cdb_geocode_namedplace_point('test_user', 'test_orgname', 'Elx', 'Valencia', 'Spain');

-- Insert dummy data into points table
INSERT INTO global_cities_points_limited (geoname_id, name, iso2, admin1, admin2, population, lowername, the_geom) VALUES (3128760, 'Elche', 'ES', 'Valencia', 'AL', 34534, 'elche', ST_GeomFromText(
  'POINT(0.6983 39.26787)',4326)
);

-- Insert dummy data into alternates table
INSERT INTO global_cities_alternates_limited (geoname_id, name, preferred, lowername, admin1_geonameid, iso2, admin1, the_geom) VALUES (3128760, 'Elx', true, 'elx', '000000', 'ES', 'Valencia', ST_GeomFromText(
  'POINT(0.6983 39.26787)',4326)
);

-- Insert dummy data into country decoder table
INSERT INTO country_decoder (synonyms, iso2) VALUES (Array['spain'], 'ES');

-- Insert dummy data into admin1 decoder table
INSERT INTO admin1_decoder (admin1, synonyms, iso2) VALUES ('Valencia', Array['valencia', 'Valencia'], 'ES');

-- This should return the point inserted above
SELECT cdb_dataservices_server.cdb_geocode_namedplace_point('test_user', 'test_orgname', 'Elx');
SELECT cdb_dataservices_server.cdb_geocode_namedplace_point('test_user', 'test_orgname', 'Elche');
SELECT cdb_dataservices_server.cdb_geocode_namedplace_point('test_user', 'test_orgname', 'Elx', 'Spain');
SELECT cdb_dataservices_server.cdb_geocode_namedplace_point('test_user', 'test_orgname', 'Elche', 'Spain');
SELECT cdb_dataservices_server.cdb_geocode_namedplace_point('test_user', 'test_orgname', 'Elx', 'Valencia', 'Spain');
SELECT cdb_dataservices_server.cdb_geocode_namedplace_point('test_user', 'test_orgname', 'Elche', 'valencia', 'Spain');

-- Check for namedplaces signatures
SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'cdb_geocode_namedplace_point'
              AND oidvectortypes(p.proargtypes)  = 'text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'cdb_geocode_namedplace_point'
              AND oidvectortypes(p.proargtypes)  = 'text, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = 'cdb_geocode_namedplace_point'
              AND oidvectortypes(p.proargtypes)  = 'text, text, text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = '_cdb_geocode_namedplace_point'
              AND oidvectortypes(p.proargtypes)  = 'text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = '_cdb_geocode_namedplace_point'
              AND oidvectortypes(p.proargtypes)  = 'text, text');

SELECT exists(SELECT *
              FROM pg_proc p
              INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
              WHERE ns.nspname = 'cdb_dataservices_server'
              AND proname = '_cdb_geocode_namedplace_point'
              AND oidvectortypes(p.proargtypes)  = 'text, text, text');
