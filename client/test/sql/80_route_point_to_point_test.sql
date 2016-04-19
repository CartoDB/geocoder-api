-- Add to the search path the schema
SET search_path TO public,cartodb,cdb_dataservices_client;

-- Mock the server functions

CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_route_point_to_point (username text, orgname text, origin geometry(Point, 4326), destination geometry(Point, 4326), mode TEXT, options text[] DEFAULT ARRAY[]::text[], units text DEFAULT 'kilometers')
RETURNS cdb_dataservices_client.simple_route AS $$
DECLARE 
  ret cdb_dataservices_client.simple_route;
BEGIN
  RAISE NOTICE 'cdb_dataservices_server.cdb_route_point_to_point invoked with params (%, %, %, %, %, %, %)', username, orgname, origin, destination, mode, options, units;
  SELECT NULL, 5.33, 100 INTO ret;
  RETURN ret;
END;
$$ LANGUAGE 'plpgsql';


-- Exercise the public and the proxied function
SELECT cdb_route_point_to_point('POINT(-87.81406 41.89308)'::geometry,'POINT(-87.79209 41.86138)'::geometry, 'car');
SELECT cdb_route_point_to_point('POINT(-87.81406 41.89308)'::geometry,'POINT(-87.79209 41.86138)'::geometry, 'car', ARRAY['mode_type=shortest']::text[]);
SELECT cdb_route_point_to_point('POINT(-87.81406 41.89308)'::geometry,'POINT(-87.79209 41.86138)'::geometry, 'car', ARRAY[]::text[], 'miles');
