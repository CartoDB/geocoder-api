--DO NOT MODIFY THIS FILE, IT IS GENERATED AUTOMATICALLY FROM SOURCES
-- Complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION cdb_dataservices_server UPDATE TO '0.8.0'" to load this file. \quit

DROP FUNCTION IF EXISTS cdb_dataservices_server.cdb_route_with_waypoints(text, text, geometry(Geometry, 4326)[], text, text[], text);
DROP FUNCTION IF EXISTS cdb_dataservices_server._cdb_mapzen_route_with_waypoints(text, text, geometry(Geometry, 4326)[], text, text[], text);

CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_mapzen_route_point_to_point(
  username TEXT,
  orgname TEXT,
  origin geometry(Point, 4326),
  destination geometry(Point, 4326),
  mode TEXT,
  options text[] DEFAULT ARRAY[]::text[],
  units text DEFAULT 'kilometers')
RETURNS cdb_dataservices_server.simple_route AS $$
  import json
  from cartodb_services.mapzen import MapzenRouting, MapzenRoutingResponse
  from cartodb_services.mapzen.types import polyline_to_linestring
  from cartodb_services.metrics import QuotaService
  from cartodb_services.tools import Coordinate

  redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
  user_routing_config = GD["user_routing_config_{0}".format(username)]

  quota_service = QuotaService(user_routing_config, redis_conn)
  if not quota_service.check_user_quota():
    plpy.error('You have reached the limit of your quota')

  try:
    client = MapzenRouting(user_routing_config.mapzen_api_key)

    if not origin or not destination:
      plpy.notice("Empty origin or destination")
      quota_service.increment_empty_service_use()
      return [None, None, None]

    orig_lat = plpy.execute("SELECT ST_Y('%s') AS lat" % origin)[0]['lat']
    orig_lon = plpy.execute("SELECT ST_X('%s') AS lon" % origin)[0]['lon']
    origin_coordinates = Coordinate(orig_lon, orig_lat)
    dest_lat = plpy.execute("SELECT ST_Y('%s') AS lat" % destination)[0]['lat']
    dest_lon = plpy.execute("SELECT ST_X('%s') AS lon" % destination)[0]['lon']
    dest_coordinates = Coordinate(dest_lon, dest_lat)

    resp = client.calculate_route_point_to_point(origin_coordinates, dest_coordinates, mode, options, units)

    if resp and resp.shape:
      shape_linestring = polyline_to_linestring(resp.shape)
      if shape_linestring:
        quota_service.increment_success_service_use()
        return [shape_linestring, resp.length, resp.duration]
      else:
        quota_service.increment_empty_service_use()
        return [None, None, None]
    else:
      quota_service.increment_empty_service_use()
      return [None, None, None]
  except BaseException as e:
    import sys, traceback
    type_, value_, traceback_ = sys.exc_info()
    quota_service.increment_failed_service_use()
    error_msg = 'There was an error trying to obtain route using mapzen provider: {0}'.format(e)
    plpy.notice(traceback.format_tb(traceback_))
    plpy.error(error_msg)
  finally:
    quota_service.increment_total_service_use()
$$ LANGUAGE plpythonu SECURITY DEFINER;

CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_route_point_to_point(
  username TEXT,
  orgname TEXT,
  origin geometry(Point, 4326),
  destination geometry(Point, 4326),
  mode TEXT,
  options text[] DEFAULT ARRAY[]::text[],
  units text DEFAULT 'kilometers')
RETURNS cdb_dataservices_server.simple_route AS $$
  plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
  redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
  plpy.execute("SELECT cdb_dataservices_server._get_routing_config({0}, {1})".format(plpy.quote_nullable(username), plpy.quote_nullable(orgname)))
  user_routing_config = GD["user_routing_config_{0}".format(username)]

  mapzen_plan = plpy.prepare("SELECT * FROM cdb_dataservices_server._cdb_mapzen_route_point_to_point($1, $2, $3, $4, $5, $6, $7) as route;", ["text", "text", "geometry(Point, 4326)", "geometry(Point, 4326)", "text", "text[]", "text"])
  result = plpy.execute(mapzen_plan, [username, orgname, origin, destination, mode, options, units])
  return [result[0]['shape'],result[0]['length'], result[0]['duration']]
$$ LANGUAGE plpythonu;