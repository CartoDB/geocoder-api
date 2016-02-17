ALTER TYPE cdb_dataservices_server._redis_conf_params ADD ATTRIBUTE redis_host text;

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
        "sentinel_host": params['sentinel_host'],
        "sentinel_port": params['sentinel_port'],
        "sentinel_master_id": params['sentinel_master_id'],
        "redis_host": params['redis_host']
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
    metadata_config_params = plpy.execute("""select c.sentinel_host, c.sentinel_port,
        c.sentinel_master_id, c.redis_host, c.timeout, c.redis_db
        from cdb_dataservices_server._get_redis_conf_v2('redis_metadata_config') c;""")[0]
    metrics_config_params = plpy.execute("""select c.sentinel_host, c.sentinel_port,
        c.sentinel_master_id, c.redis_host, c.timeout, c.redis_db
        from cdb_dataservices_server._get_redis_conf_v2('redis_metrics_config') c;""")[0]
    redis_metadata_connection = RedisConnection(metadata_config_params['sentinel_host'],
        metadata_config_params['sentinel_port'],
        metadata_config_params['sentinel_master_id'],
        metadata_config_params['redis_host'],
        timeout=metadata_config_params['timeout'],
        redis_db=metadata_config_params['redis_db']).redis_connection()
    redis_metrics_connection = RedisConnection(metrics_config_params['sentinel_host'],
        metrics_config_params['sentinel_port'],
        metrics_config_params['sentinel_master_id'],
        metrics_config_params['redis_host'],
        timeout=metrics_config_params['timeout'],
        redis_db=metrics_config_params['redis_db']).redis_connection()
    GD[cache_key] = {
      'redis_metadata_connection': redis_metadata_connection,
      'redis_metrics_connection': redis_metrics_connection,
    }
    return True
$$ LANGUAGE plpythonu SECURITY DEFINER;
