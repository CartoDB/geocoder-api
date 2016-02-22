--DO NOT MODIFY THIS FILE, IT IS GENERATED AUTOMATICALLY FROM SOURCES
-- Complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION cdb_dataservices_server" to load this file. \quit
CREATE TYPE cdb_dataservices_server._redis_conf_params AS (
    sentinel_master_id text,
    redis_host text,
    redis_port int,
    redis_db text,
    timeout float
);

-- Get the Redis configuration from the _conf table --
CREATE OR REPLACE FUNCTION cdb_dataservices_server._get_redis_conf_v2(config_key text)
RETURNS cdb_dataservices_server._redis_conf_params AS $$
    conf_query = "SELECT cartodb.CDB_Conf_GetConf('{0}') as conf".format(config_key)
    conf = plpy.execute(conf_query)[0]['conf']
    if conf is None:
      plpy.error("There is no redis configuration defined")
    else:
      import json
      params = json.loads(conf)
      return {
        "sentinel_master_id": params['sentinel_master_id'],
        "redis_host": params['redis_host'],
        "redis_port": params['redis_port'],
        "timeout": params['timeout'],
        "redis_db": params['redis_db']
      }
$$ LANGUAGE plpythonu;

-- Get the connection to redis from cache or create a new one
CREATE OR REPLACE FUNCTION cdb_dataservices_server._connect_to_redis(user_id text)
RETURNS boolean AS $$
  cache_key = "redis_connection_{0}".format(user_id)
  if cache_key in GD:
    return False
  else:
    from cartodb_services.tools import RedisConnection
    metadata_config_params = plpy.execute("""select c.sentinel_master_id, c.redis_host, 
        c.redis_port, c.timeout, c.redis_db
        from cdb_dataservices_server._get_redis_conf_v2('redis_metadata_config') c;""")[0]
    metrics_config_params = plpy.execute("""select c.sentinel_master_id, c.redis_host, 
        c.redis_port, c.timeout, c.redis_db
        from cdb_dataservices_server._get_redis_conf_v2('redis_metrics_config') c;""")[0]
    redis_metadata_connection = RedisConnection(metadata_config_params['sentinel_master_id'],
        metadata_config_params['redis_host'],
        metadata_config_params['redis_port'],
        timeout=metadata_config_params['timeout'],
        redis_db=metadata_config_params['redis_db']).redis_connection()
    redis_metrics_connection = RedisConnection(metrics_config_params['sentinel_master_id'],
        metrics_config_params['redis_host'],
        metrics_config_params['redis_port'],
        timeout=metrics_config_params['timeout'],
        redis_db=metrics_config_params['redis_db']).redis_connection()
    GD[cache_key] = {
      'redis_metadata_connection': redis_metadata_connection,
      'redis_metrics_connection': redis_metrics_connection,
    }
    return True
$$ LANGUAGE plpythonu SECURITY DEFINER;
-- Get the Redis configuration from the _conf table --
CREATE OR REPLACE FUNCTION cdb_dataservices_server._get_geocoder_config(username text, orgname text)
RETURNS boolean AS $$
  cache_key = "user_geocoder_config_{0}".format(username)
  if cache_key in GD:
    return False
  else:
    import json
    from cartodb_services.metrics import GeocoderConfig
    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metadata_connection']
    heremaps_conf_json = plpy.execute("SELECT cartodb.CDB_Conf_GetConf('heremaps_conf') as heremaps_conf", 1)[0]['heremaps_conf']
    if not heremaps_conf_json:
      heremaps_app_id = None
      heremaps_app_code = None
    else:
      heremaps_conf = json.loads(heremaps_conf_json)
      heremaps_app_id = heremaps_conf['app_id']
      heremaps_app_code = heremaps_conf['app_code']
    geocoder_config = GeocoderConfig(redis_conn, username, orgname, heremaps_app_id, heremaps_app_code)
    # --Think about the security concerns with this kind of global cache, it should be only available
    # --for this user session but...
    GD[cache_key] = geocoder_config
    return True
$$ LANGUAGE plpythonu SECURITY DEFINER;

-- Get the Redis configuration from the _conf table --
CREATE OR REPLACE FUNCTION cdb_dataservices_server._get_routing_config(username text, orgname text)
RETURNS boolean AS $$
  cache_key = "user_routing_config_{0}".format(username)
  if cache_key in GD:
    return False
  else:
    import json
    from cartodb_services.metrics import RoutingConfig
    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metadata_connection']
    heremaps_conf_json = plpy.execute("SELECT cartodb.CDB_Conf_GetConf('heremaps_conf') as heremaps_conf", 1)[0]['heremaps_conf']
    if not heremaps_conf_json:
      heremaps_app_id = None
      heremaps_app_code = None
    else:
      heremaps_conf = json.loads(heremaps_conf_json)
      heremaps_app_id = heremaps_conf['app_id']
      heremaps_app_code = heremaps_conf['app_code']
    routing_config = RoutingConfig(redis_conn, username, orgname, heremaps_app_id, heremaps_app_code)
    # --Think about the security concerns with this kind of global cache, it should be only available
    # --for this user session but...
    GD[cache_key] = routing_config
    return True
$$ LANGUAGE plpythonu SECURITY DEFINER;
-- Geocodes a street address given a searchtext and a state and/or country
CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_street_point(username TEXT, orgname TEXT, searchtext TEXT, city TEXT DEFAULT NULL, state_province TEXT DEFAULT NULL, country TEXT DEFAULT NULL)
RETURNS Geometry AS $$
  plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
  redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
  plpy.execute("SELECT cdb_dataservices_server._get_geocoder_config({0}, {1})".format(plpy.quote_nullable(username), plpy.quote_nullable(orgname)))
  user_geocoder_config = GD["user_geocoder_config_{0}".format(username)]

  if user_geocoder_config.heremaps_geocoder:
    here_plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_here_geocode_street_point($1, $2, $3, $4, $5, $6) as point; ", ["text", "text", "text", "text", "text", "text"])
    return plpy.execute(here_plan, [username, orgname, searchtext, city, state_province, country], 1)[0]['point']
  elif user_geocoder_config.google_geocoder:
    google_plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_google_geocode_street_point($1, $2, $3, $4, $5, $6) as point; ", ["text", "text", "text", "text", "text", "text"])
    return plpy.execute(google_plan, [username, orgname, searchtext, city, state_province, country], 1)[0]['point']
  else:
    plpy.error('Requested geocoder is not available')

$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_here_geocode_street_point(username TEXT, orgname TEXT, searchtext TEXT, city TEXT DEFAULT NULL, state_province TEXT DEFAULT NULL, country TEXT DEFAULT NULL)
RETURNS Geometry AS $$
  from cartodb_services.here import HereMapsGeocoder
  from cartodb_services.metrics import QuotaService

  redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
  user_geocoder_config = GD["user_geocoder_config_{0}".format(username)]

  # -- Check the quota
  quota_service = QuotaService(user_geocoder_config, redis_conn)
  if not quota_service.check_user_quota():
    plpy.error('You have reach the limit of your quota')

  try:
    geocoder = HereMapsGeocoder(user_geocoder_config.heremaps_app_id, user_geocoder_config.heremaps_app_code)
    coordinates = geocoder.geocode(searchtext=searchtext, city=city, state=state_province, country=country)
    if coordinates:
      quota_service.increment_success_geocoder_use()
      plan = plpy.prepare("SELECT ST_SetSRID(ST_MakePoint($1, $2), 4326); ", ["double precision", "double precision"])
      point = plpy.execute(plan, [coordinates[0], coordinates[1]], 1)[0]
      return point['st_setsrid']
    else:
      quota_service.increment_empty_geocoder_use()
      return None
  except BaseException as e:
    import sys, traceback
    type_, value_, traceback_ = sys.exc_info()
    quota_service.increment_failed_geocoder_use()
    error_msg = 'There was an error trying to geocode using here maps geocoder: {0}'.format(e)
    plpy.notice(traceback.format_tb(traceback_))
    plpy.error(error_msg)
  finally:
    quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_google_geocode_street_point(username TEXT, orgname TEXT, searchtext TEXT, city TEXT DEFAULT NULL, state_province TEXT DEFAULT NULL, country TEXT DEFAULT NULL)
RETURNS Geometry AS $$
  from cartodb_services.google import GoogleMapsGeocoder
  from cartodb_services.metrics import QuotaService

  redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
  user_geocoder_config = GD["user_geocoder_config_{0}".format(username)]
  quota_service = QuotaService(user_geocoder_config, redis_conn)

  try:
    geocoder = GoogleMapsGeocoder(user_geocoder_config.google_client_id, user_geocoder_config.google_api_key)
    coordinates = geocoder.geocode(searchtext=searchtext, city=city, state=state_province, country=country)
    if coordinates:
      quota_service.increment_success_geocoder_use()
      plan = plpy.prepare("SELECT ST_SetSRID(ST_MakePoint($1, $2), 4326); ", ["double precision", "double precision"])
      point = plpy.execute(plan, [coordinates[0], coordinates[1]], 1)[0]
      return point['st_setsrid']
    else:
      quota_service.increment_empty_geocoder_use()
      return None
  except BaseException as e:
    import sys, traceback
    type_, value_, traceback_ = sys.exc_info()
    quota_service.increment_failed_geocoder_use()
    error_msg = 'There was an error trying to geocode using google maps geocoder: {0}'.format(e)
    plpy.notice(traceback.format_tb(traceback_))
    plpy.error(error_msg)
  finally:
    quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;
CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_admin0_polygon(username text, orgname text, country_name text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_admin0_polygon(trim($1)) AS mypolygon", ["text"])
      rv = plpy.execute(plan, [country_name], 1)
      result = rv[0]["mypolygon"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;


--------------------------------------------------------------------------------

-- Implementation of the server extension
-- Note: these functions depend on the cdb_geocoder extension
CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_admin0_polygon(country_name text)
RETURNS Geometry AS $$
  DECLARE
    ret Geometry;
  BEGIN
    SELECT n.the_geom as geom INTO ret
      FROM (SELECT q, lower(regexp_replace(q, '[^a-zA-Z\u00C0-\u00ff]+', '', 'g'))::text x
        FROM (SELECT country_name q) g) d
      LEFT OUTER JOIN admin0_synonyms s ON name_ = d.x
      LEFT OUTER JOIN ne_admin0_v3 n ON s.adm0_a3 = n.adm0_a3 GROUP BY d.q, n.the_geom, s.adm0_a3;

    RETURN ret;
  END
$$ LANGUAGE plpgsql;
---- cdb_geocode_admin1_polygon(admin1_name text)
CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_admin1_polygon(username text, orgname text, admin1_name text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_admin1_polygon(trim($1)) AS mypolygon", ["text"])
      rv = plpy.execute(plan, [admin1_name], 1)
      result = rv[0]["mypolygon"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

---- cdb_geocode_admin1_polygon(admin1_name text, country_name text)
CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_admin1_polygon(username text, orgname text, admin1_name text, country_name text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_admin1_polygon(trim($1), trim($2)) AS mypolygon", ["text", "text"])
      rv = plpy.execute(plan, [admin1_name, country_name], 1)
      result = rv[0]["mypolygon"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

--------------------------------------------------------------------------------

-- Implementation of the server extension
-- Note: these functions depend on the cdb_geocoder extension

---- cdb_geocode_admin1_polygon(admin1_name text)
CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_admin1_polygon(admin1_name text)
RETURNS Geometry AS $$
  DECLARE
    ret Geometry;
  BEGIN
    SELECT geom INTO ret
    FROM (
      SELECT q, (
          SELECT the_geom
          FROM global_province_polygons
          WHERE d.c = ANY (synonyms)
          ORDER BY frequency DESC LIMIT 1
        ) geom
      FROM (
        SELECT
          trim(replace(lower(admin1_name),'.',' ')) c, admin1_name q
        ) d
      ) v;

    RETURN ret;
  END
$$ LANGUAGE plpgsql;

---- cdb_geocode_admin1_polygon(admin1_name text, country_name text)
CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_admin1_polygon(admin1_name text, country_name text)
RETURNS Geometry AS $$
  DECLARE
    ret Geometry;
  BEGIN
    WITH p AS (SELECT r.c, r.q, (SELECT iso3 FROM country_decoder WHERE lower(country_name) = ANY (synonyms)) i FROM (SELECT  trim(replace(lower(admin1_name),'.',' ')) c, country_name q) r)
    SELECT
      geom INTO ret
    FROM (
      SELECT
        q, (
          SELECT the_geom
          FROM global_province_polygons
          WHERE p.c = ANY (synonyms)
          AND iso3 = p.i
          ORDER BY frequency DESC LIMIT 1
        ) geom
      FROM p) n;

    RETURN ret;
  END
$$ LANGUAGE plpgsql;

---- cdb_geocode_namedplace_point(city_name text)
CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_namedplace_point(username text, orgname text, city_name text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_namedplace_point(trim($1)) AS mypoint", ["text"])
      rv = plpy.execute(plan, [city_name], 1)
      result = rv[0]["mypoint"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

---- cdb_geocode_namedplace_point(city_name text, country_name text)
CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_namedplace_point(username text, orgname text, city_name text, country_name text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_namedplace_point(trim($1), trim($2)) AS mypoint", ["text", "text"])
      rv = plpy.execute(plan, [city_name, country_name], 1)
      result = rv[0]["mypoint"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

---- cdb_geocode_namedplace_point(city_name text, admin1_name text, country_name text)
CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_namedplace_point(username text, orgname text, city_name text, admin1_name text, country_name text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_namedplace_point(trim($1), trim($2), trim($3)) AS mypoint", ["text", "text", "text"])
      rv = plpy.execute(plan, [city_name, admin1_name, country_name], 1)
      result = rv[0]["mypoint"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

--------------------------------------------------------------------------------

-- Implementation of the server extension
-- Note: these functions depend on the cdb_geocoder extension

---- cdb_geocode_namedplace_point(city_name text)
CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_namedplace_point(city_name text)
RETURNS Geometry AS $$
  DECLARE
    ret Geometry;
  BEGIN
  SELECT geom INTO ret
  FROM (
    WITH best AS (SELECT s AS q, (SELECT the_geom FROM global_cities_points_limited gp WHERE gp.lowername = lower(p.s) ORDER BY population DESC LIMIT 1) AS geom FROM (SELECT city_name as s) p),
        next AS (SELECT p.s AS q, (SELECT gp.the_geom FROM global_cities_points_limited gp, global_cities_alternates_limited ga WHERE lower(p.s) = ga.lowername AND ga.geoname_id = gp.geoname_id ORDER BY preferred DESC LIMIT 1) geom FROM (SELECT city_name as s) p WHERE p.s NOT IN (SELECT q FROM best WHERE geom IS NOT NULL))
        SELECT q, geom, TRUE AS success FROM best WHERE geom IS NOT NULL
        UNION ALL
        SELECT q, geom, CASE WHEN geom IS NULL THEN FALSE ELSE TRUE END AS success FROM next
  ) v;

    RETURN ret;
  END
$$ LANGUAGE plpgsql;

---- cdb_geocode_namedplace_point(city_name text, country_name text)
CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_namedplace_point(city_name text, country_name text)
RETURNS Geometry AS $$
  DECLARE
    ret Geometry;
  BEGIN
  SELECT geom INTO ret
  FROM (
    WITH p AS (SELECT r.s, r.c, (SELECT iso2 FROM country_decoder WHERE lower(r.c) = ANY (synonyms)) i FROM (SELECT city_name AS s, country_name::text AS c) r),
        best AS (SELECT p.s AS q, p.c AS c, (SELECT gp.the_geom AS geom FROM global_cities_points_limited gp WHERE gp.lowername = lower(p.s) AND gp.iso2 = p.i ORDER BY population DESC LIMIT 1) AS geom FROM p),
        next AS (SELECT p.s AS q, p.c AS c, (SELECT gp.the_geom FROM global_cities_points_limited gp, global_cities_alternates_limited ga WHERE lower(p.s) = ga.lowername AND gp.iso2 = p.i AND ga.geoname_id = gp.geoname_id ORDER BY preferred DESC LIMIT 1) geom FROM p WHERE p.s NOT IN (SELECT q FROM best WHERE c = p.c AND geom IS NOT NULL))
        SELECT geom FROM best WHERE geom IS NOT NULL
        UNION ALL
        SELECT geom FROM next
   ) v;

    RETURN ret;
  END
$$ LANGUAGE plpgsql;

---- cdb_geocode_namedplace_point(city_name text, admin1_name text, country_name text)
CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_namedplace_point(city_name text, admin1_name text, country_name text)
RETURNS Geometry AS $$
  DECLARE
    ret Geometry;
  BEGIN
  SELECT geom INTO ret
  FROM (
    WITH inputcountry AS (
        SELECT iso2 as isoTwo FROM country_decoder WHERE lower(country_name) = ANY (synonyms) LIMIT 1
        ),
    p AS (
       SELECT r.s, r.a1, (SELECT admin1 FROM admin1_decoder, inputcountry WHERE lower(r.a1) = ANY (synonyms) AND admin1_decoder.iso2 = inputcountry.isoTwo LIMIT 1) i FROM (SELECT city_name AS s, admin1_name::text AS a1) r),
       best AS (SELECT p.s AS q, p.a1 as a1, (SELECT gp.the_geom AS geom FROM global_cities_points_limited gp WHERE gp.lowername = lower(p.s) AND gp.admin1 = p.i ORDER BY population DESC LIMIT 1) AS geom FROM p),
       next AS (SELECT p.s AS q, p.a1 AS a1, (SELECT gp.the_geom FROM global_cities_points_limited gp, global_cities_alternates_limited ga WHERE lower(p.s) = ga.lowername AND ga.admin1 = p.i AND ga.geoname_id = gp.geoname_id ORDER BY preferred DESC LIMIT 1) geom FROM p WHERE p.s NOT IN (SELECT q FROM best WHERE geom IS NOT NULL))
       SELECT geom FROM best WHERE geom IS NOT NULL
       UNION ALL
       SELECT geom FROM next
   ) v;

    RETURN ret;
  END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_postalcode_point(username text, orgname text, code text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_postalcode_point(trim($1)) AS mypoint", ["text"])
      rv = plpy.execute(plan, [code], 1)
      result = rv[0]["mypoint"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_postalcode_point(username text, orgname text, code text, country text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_postalcode_point(trim($1), trim($2)) AS mypoint", ["TEXT", "TEXT"])
      rv = plpy.execute(plan, [code, country], 1)
      result = rv[0]["mypoint"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_postalcode_polygon(username text, orgname text, code text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_postalcode_polygon(trim($1)) AS mypolygon", ["text"])
      rv = plpy.execute(plan, [code], 1)
      result = rv[0]["mypolygon"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_postalcode_polygon(username text, orgname text, code text, country text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_postalcode_polygon(trim($1), trim($2)) AS mypolygon", ["TEXT", "TEXT"])
      rv = plpy.execute(plan, [code, country], 1)
      result = rv[0]["mypolygon"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

--------------------------------------------------------------------------------

-- Implementation of the server extension
-- Note: these functions depend on the cdb_geocoder extension
CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_postalcode_point(code text)
RETURNS Geometry AS $$
  DECLARE
    ret Geometry;
  BEGIN
    SELECT geom INTO ret
    FROM (
      SELECT
        q, (
          SELECT the_geom
          FROM global_postal_code_points
          WHERE postal_code = upper(d.q)
          LIMIT 1
        ) geom
      FROM (SELECT code q) d
    ) v;

    RETURN ret;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_postalcode_point(code text, country text)
RETURNS Geometry AS $$
  DECLARE
    ret Geometry;
  BEGIN
    SELECT geom INTO ret
    FROM (
      SELECT
        q, (
          SELECT the_geom
          FROM global_postal_code_points
          WHERE postal_code = upper(d.q)
            AND iso3 = (
                SELECT iso3 FROM country_decoder WHERE
                lower(country) = ANY (synonyms) LIMIT 1
            )
          LIMIT 1
        ) geom
      FROM (SELECT code q) d
    ) v;

    RETURN ret;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_postalcode_polygon(code text)
RETURNS Geometry AS $$
  DECLARE
    ret Geometry;
  BEGIN
    SELECT geom INTO ret
    FROM (
      SELECT
        q, (
          SELECT the_geom
          FROM global_postal_code_polygons
          WHERE postal_code = upper(d.q)
          LIMIT 1
        ) geom
      FROM (SELECT code q) d
    ) v;

    RETURN ret;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_postalcode_polygon(code text, country text)
RETURNS Geometry AS $$
  DECLARE
    ret Geometry;
  BEGIN
    SELECT geom INTO ret
    FROM (
      SELECT
        q, (
          SELECT the_geom
          FROM global_postal_code_polygons
          WHERE postal_code = upper(d.q)
            AND iso3 = (
                SELECT iso3 FROM country_decoder WHERE
                lower(country) = ANY (synonyms) LIMIT 1
            )
          LIMIT 1
        ) geom
      FROM (SELECT code q) d
    ) v;

    RETURN ret;
END
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_geocode_ipaddress_point(username text, orgname text, ip text)
RETURNS Geometry AS $$
    from cartodb_services.metrics import QuotaService
    from cartodb_services.metrics import InternalGeocoderConfig

    plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
    redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
    user_geocoder_config = InternalGeocoderConfig(redis_conn, username, orgname)

    quota_service = QuotaService(user_geocoder_config, redis_conn)
    try:
      plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_geocode_ipaddress_point(trim($1)) AS mypoint", ["TEXT"])
      rv = plpy.execute(plan, [ip], 1)
      result = rv[0]["mypoint"]
      if result:
        quota_service.increment_success_geocoder_use()
        return result
      else:
        quota_service.increment_empty_geocoder_use()
        return None
    except BaseException as e:
      import sys, traceback
      type_, value_, traceback_ = sys.exc_info()
      quota_service.increment_failed_geocoder_use()
      error_msg = 'There was an error trying to geocode using admin0 geocoder: {0}'.format(e)
      plpy.notice(traceback.format_tb(traceback_))
      plpy.error(error_msg)
    finally:
      quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu;

--------------------------------------------------------------------------------

-- Implementation of the server extension
-- Note: these functions depend on the cdb_geocoder extension
CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_geocode_ipaddress_point(ip text)
RETURNS Geometry AS $$
    DECLARE
        ret Geometry;

        new_ip INET;
    BEGIN
    BEGIN
        IF family(ip::inet) = 6 THEN
            new_ip := ip::inet;
        ELSE
            new_ip := ('::ffff:' || ip)::inet;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        SELECT NULL as geom INTO ret;
        RETURN ret;
    END;

    WITH
        ips AS (SELECT ip s, new_ip net),
        matches AS (SELECT s, (SELECT the_geom FROM ip_address_locations WHERE network_start_ip <= ips.net ORDER BY network_start_ip DESC LIMIT 1) geom FROM ips)
    SELECT geom INTO ret
        FROM matches;
    RETURN ret;
END
$$ LANGUAGE plpgsql;
CREATE TYPE cdb_dataservices_server.isoline AS (center geometry(Geometry,4326), data_range integer, the_geom geometry(Multipolygon,4326));

CREATE OR REPLACE FUNCTION cdb_dataservices_server._cdb_here_routing_isolines(username TEXT, orgname TEXT, type TEXT, source geometry(Geometry, 4326), mode TEXT, data_range integer[], options text[])
RETURNS SETOF cdb_dataservices_server.isoline AS $$
  import json
  from cartodb_services.here import HereMapsRoutingIsoline
  from cartodb_services.metrics import QuotaService
  from cartodb_services.here.types import geo_polyline_to_multipolygon

  redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
  user_routing_config = GD["user_routing_config_{0}".format(username)]

  quota_service = QuotaService(user_routing_config, redis_conn)

  try:
    client = HereMapsRoutingIsoline(user_routing_config.heremaps_app_id, user_routing_config.heremaps_app_code, base_url = HereMapsRoutingIsoline.PRODUCTION_ROUTING_BASE_URL)

    if source:
      lat = plpy.execute("SELECT ST_Y('%s') AS lat" % source)[0]['lat']
      lon = plpy.execute("SELECT ST_X('%s') AS lon" % source)[0]['lon']
      source_str = 'geo!%f,%f' % (lat, lon)
    else:
      source_str = None

    if type == 'isodistance':
      resp = client.calculate_isodistance(source_str, mode, data_range, options)
    elif type == 'isochrone':
      resp = client.calculate_isochrone(source_str, mode, data_range, options)

    if resp:
      result = []
      for isoline in resp:
        data_range_n = isoline['range']
        polyline = isoline['geom']
        multipolygon = geo_polyline_to_multipolygon(polyline)
        result.append([source, data_range_n, multipolygon])
      quota_service.increment_success_geocoder_use()
      quota_service.increment_isolines_service_use(len(resp))
      return result
    else:
      quota_service.increment_empty_geocoder_use()
  except BaseException as e:
    import sys, traceback
    type_, value_, traceback_ = sys.exc_info()
    quota_service.increment_failed_geocoder_use()
    error_msg = 'There was an error trying to obtain isodistances using here maps geocoder: {0}'.format(e)
    plpy.notice(traceback.format_tb(traceback_))
    plpy.error(error_msg)
  finally:
    quota_service.increment_total_geocoder_use()
$$ LANGUAGE plpythonu SECURITY DEFINER;
CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_isodistance(username TEXT, orgname TEXT, source geometry(Geometry, 4326), mode TEXT, range integer[], options text[] DEFAULT array[]::text[])
RETURNS SETOF cdb_dataservices_server.isoline AS $$
  plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
  redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
  plpy.execute("SELECT cdb_dataservices_server._get_routing_config({0}, {1})".format(plpy.quote_nullable(username), plpy.quote_nullable(orgname)))
  user_isolines_config = GD["user_routing_config_{0}".format(username)]
  type = 'isodistance'

  here_plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_here_routing_isolines($1, $2, $3, $4, $5, $6, $7) as isoline; ", ["text", "text", "text", "geometry(Geometry, 4326)", "text", "integer[]", "text[]"])
  result = plpy.execute(here_plan, [username, orgname, type, source, mode, range, options])
  isolines = []
  for element in result:
    isoline = element['isoline']
    isoline = isoline.translate(None, "()").split(',')
    isolines.append(isoline)

  return isolines
$$ LANGUAGE plpythonu;
CREATE OR REPLACE FUNCTION cdb_dataservices_server.cdb_isochrone(username TEXT, orgname TEXT, source geometry(Geometry, 4326), mode TEXT, range integer[], options text[] DEFAULT array[]::text[])
RETURNS SETOF cdb_dataservices_server.isoline AS $$
  plpy.execute("SELECT cdb_dataservices_server._connect_to_redis('{0}')".format(username))
  redis_conn = GD["redis_connection_{0}".format(username)]['redis_metrics_connection']
  plpy.execute("SELECT cdb_dataservices_server._get_routing_config({0}, {1})".format(plpy.quote_nullable(username), plpy.quote_nullable(orgname)))
  user_isolines_config = GD["user_routing_config_{0}".format(username)]
  type = 'isochrone'

  here_plan = plpy.prepare("SELECT cdb_dataservices_server._cdb_here_routing_isolines($1, $2, $3, $4, $5, $6, $7) as isoline; ", ["text", "text", "text", "geometry(Geometry, 4326)", "text", "integer[]", "text[]"])
  result = plpy.execute(here_plan, [username, orgname, type, source, mode, range, options])
  isolines = []
  for element in result:
    isoline = element['isoline']
    isoline = isoline.translate(None, "()").split(',')
    isolines.append(isoline)

  return isolines
$$ LANGUAGE plpythonu;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT *
        FROM   pg_catalog.pg_user
        WHERE  usename = 'geocoder_api') THEN

            CREATE USER geocoder_api;
    END IF;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cdb_dataservices_server TO geocoder_api;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO geocoder_api;
    GRANT USAGE ON SCHEMA cdb_dataservices_server TO geocoder_api;
    GRANT USAGE ON SCHEMA public TO geocoder_api;
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO geocoder_api;
END$$;
