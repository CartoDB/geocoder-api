# Isoline functions

The following functions provide an isolines generator service based on time or distance. This service uses the isolines service defined for the user (currently, only the [HERE](https://developer.here.com/coverage-info) isolines service is available).

**This service is subject to quota limitations, and extra fees may apply**. Please view our [terms and conditions](https://cartodb.com/terms/) and check out the [Quota information section](http://docs.cartodb.com/cartodb-platform/dataservices-api/quota-information/) for details and recommendations related with quota usage.

### cdb_isodistance(_source geometry, mode text, range integer[], [options text[]]_)

#### Arguments

Name | Type | Description | Accepted values
--- | --- | --- | ---
`source` | `geometry` | Source point, in 4326 projection, which defines the start location. |
`mode` | `text` | Type of transport used to calculate the isolines. | `car` or `walk`
`range` | `integer[]` | Range of the isoline, in meters. |
`options` | `text[]` | (Optional) Multiple options to add more capabilities to the analysis. See [Optional isolines parameters](#optional-isoline-parameters) for details.


#### Returns

Name | Type | Description
--- | --- | ---
`center` | `geometry` | Source point, in 4326 projection, which defines the start location.
`data_range` | `integer` | The range that belongs to the generated isoline.
`the_geom` | `geometry(MultiPolygon)` | MultiPolygon geometry of the generated isoline in the 4326 projection.

#### Examples

##### Select the results of the isodistance function

```bash
SELECT * FROM cdb_isodistance('POINT(-3.70568 40.42028)'::geometry, 'car', ARRAY[1000,2000]::integer[]);
```

```bash
SELECT * FROM cdb_isodistance('POINT(-3.70568 40.42028)'::geometry, 'walk', ARRAY[1000]::integer[], ARRAY['mode_traffic=enabled','quality=3']::text[]);
```

##### Select the geometric results of the isodistance function

```bash
SELECT the_geom FROM cdb_isodistance('POINT(-3.70568 40.42028)'::geometry, 'walk', ARRAY[1000]::integer[]);
```

##### Calculate and insert the generated isolines from `points_table` table to another table

```bash
INSERT INTO {table} (the_geom) SELECT (cdb_isodistance(the_geom, 'walk', string_to_array(distance, ',')::integer[])).the_geom FROM {points_table}
```

### cdb_isochrone(_source geometry, mode text, range integer[], [options text[]]_)

#### Arguments

This function uses the same parameters and information as the `cdb_isodistance` function, with the exception that the range is measured in seconds instead of meters.

Name | Type | Description | Accepted values
--- | --- | --- | ---
`source` | `geometry` | Source point, in 4326 projection, which defines the start location. |
`mode` | `text` | Type of transport used to calculate the isolines. | `car` or `walk`
`range` | `integer[]` | Range of the isoline, in seconds. |
`options` | `text[]` | (Optional) Multiple options to add more capabilities to the analysis. See [Optional isolines parameters](#optional-isoline-parameters) for details.

#### Examples

##### Select the results of the isochrone function

```bash
SELECT * FROM cdb_isochrone('POINT(-3.70568 40.42028)'::geometry, 'car', ARRAY[300,900,12000]::integer[]);
```

```bash
SELECT * FROM cdb_isochrone('POINT(-3.70568 40.42028)'::geometry, 'walk', ARRAY[300,900]::integer[], ARRAY['mode_traffic=enabled','quality=3']::text[]);
```

##### Select the geometric results of the isochrone function

```bash
SELECT the_geom FROM cdb_isochrone('POINT(-3.70568 40.42028)'::geometry, 'walk', ARRAY[300]::integer[]);
```

##### Calculate and insert the generated isolines from `points_table` table to another table

```bash
INSERT INTO {table} (the_geom) SELECT (cdb_isochrone(the_geom, 'walk', string_to_array(time_distance, ',')::integer[])).the_geom FROM {points_table}
```

### Optional isoline parameters

The optional value parameters must be passed using the format: `option=value`.

Name | Type | Description | Accepted values
--- | --- | --- | ---
`is_destination` | `boolean` | If true, the source point is the destination instead of the starting location | `true` or `false`. `false` by default
`mode_type` | `text` | Type of route calculation | `shortest` or `fastest`. `shortest` by default
`mode_traffic` | `text` | Use traffic data to calculate the route | `enabled` or `disabled`. `disabled` by default
`resolution` | `text` | Allows you to specify the level of detail needed for the isoline polygon. Unit is meters per pixel. Higher resolution may increase the response time of the service.
`maxpoints` | `text` | Allows you to limit the amount of points in the returned isoline. If the isoline consists of multiple components, the sum of points from all components is considered. Each component will have at least two points. It is possible that more points than specified could be returned, in case when `2 * number of components` is higher than the `maxpoints` value itself. Increasing the number of `maxpoints` may increase the response time of the service.
`quality` | `text` | Allows you to reduce the quality of the isoline in favor of the response time. | `1`, `2`, `3`. Default value is `1`, corresponding to the best quality option.
