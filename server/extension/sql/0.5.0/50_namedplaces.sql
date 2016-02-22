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

