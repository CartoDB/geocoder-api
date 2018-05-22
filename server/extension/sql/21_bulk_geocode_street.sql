-- Geocodes a street address given a searchtext and a state and/or country
CREATE TYPE cdb_dataservices_client.geocoding AS (
    cartodb_id integer,
    the_geom geometry(Multipolygon,4326),
    metadata jsonb
);

CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_street_point(username TEXT, orgname TEXT, searchtext jsonb)
RETURNS SETOF cdb_dataservices_server.geocoding AS $$
  from cartodb_services.metrics import metrics
  from cartodb_services.tools import Logger,LoggerConfig
  plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
  redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
  plpy.execute("SELECT cdb_dataservices_server._get_geocoder_config({0}, {1})".format(plpy.quote_nullable(username), plpy.quote_nullable(orgname)))
  user_geocoder_config = GD["user_geocoder_config_{0}".format(username)]
  plpy.execute("SELECT cdb_dataservices_server._get_logger_config()")
  logger_config = GD["logger_config"]
  logger = Logger(logger_config)

  params = {'searchtext': searchtext}

  with metrics('cdb_geocode_street_point', user_geocoder_config, logger, params):
    if user_geocoder_config.google_geocoder:
      google_plan = plpy.prepare("SELECT * FROM cdb_dataservices_server._cdb_bulk_google_geocode_street_point($1, $2, $3); ", ["text", "text", "text", "text", "text", "text"])
      return plpy.execute(google_plan, [username, orgname, searchtext], 1)
    else:
      raise Exception('Requested geocoder is not available')

$$ LANGUAGE plpythonu STABLE PARALLEL RESTRICTED;


CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_bulk_google_geocode_street_point(username TEXT, orgname TEXT, searchtext jsonb)
RETURNS SETOF cdb_dataservices_server.geocoding AS $$
  from cartodb_services.tools import LegacyServiceManager, QuotaExceededException
  from cartodb_services.google import GoogleMapsGeocoder

  plpy.execute("SELECT cdb_dataservices_server._get_logger_config()")
  service_manager = LegacyServiceManager('geocoder', username, orgname, GD)

  try:
    service_manager.assert_within_limits(quota=False)
    geocoder = GoogleMapsGeocoder(service_manager.config.google_client_id, service_manager.config.google_api_key, service_manager.logger)
    coordinates = geocoder.bulk_geocode(searchtext=searchtext)
    if coordinates:
      result = []
      for result in results:
        plan = plpy.prepare("SELECT ST_SetSRID(ST_MakePoint($1, $2), 4326) as the_geom; ", ["double precision", "double precision"])
        point = plpy.execute(plan, [coordinates[0], coordinates[1]], 1)[0]
        result.append(result['cartodb_id'], point['the_geom'] result['metatada'])
      service_manager.quota_service.increment_success_service_use(len(result))
      return result
    else:
      service_manager.quota_service.increment_empty_service_use(len(searchtext))
      return None
  except QuotaExceededException as qe:
    service_manager.quota_service.increment_failed_service_use(len(searchtext))
    return None
  except BaseException as e:
    import sys
    service_manager.quota_service.increment_failed_service_use()
    service_manager.logger.error('Error trying to bulk geocode street point using google maps', sys.exc_info(), data={"username": username, "orgname": orgname})
    raise Exception('Error trying to bulk geocode street point using google maps')
  finally:
    service_manager.quota_service.increment_total_service_use()
$$ LANGUAGE plpythonu STABLE PARALLEL RESTRICTED;
