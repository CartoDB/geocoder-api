#!/usr/local/bin/python
# -*- coding: utf-8 -*-

from unittest import TestCase
from nose.tools import assert_not_equal, assert_equal, assert_true
from ..helpers.integration_test_helper import IntegrationTestHelper
from ..helpers.integration_test_helper import assert_close_enough, isclose

class TestStreetFunctionsSetUp(TestCase):
    provider = None
    fixture_points = None

    GOOGLE_POINTS = {
        'Plaza Mayor 1, Valladolid': [-4.728252, 41.6517025],
        'Paseo Zorrilla, Valladolid': [-4.7404453, 41.6314339],
        '1900 amphitheatre parkway': [-122.0875324, 37.4227968],
        '1901 amphitheatre parkway': [-122.0885504, 37.4238657],
        '1902 amphitheatre parkway': [-122.0876674, 37.4235729],
        'Valladolid': [-4.7245321, 41.652251],
        'Valladolid, Spain': [-4.7245321, 41.652251],
        'Valladolid, Mexico': [-88.2022488, 20.68964],
        'Madrid': [-3.7037902, 40.4167754],
        'Logroño, Spain': [-2.4449852, 42.4627195],
        'Logroño, Argentina': [-61.6961807, -29.5031057],
        'Plaza España, Barcelona': [2.1482563, 41.375485]
    }

    HERE_POINTS = {
        'Plaza Mayor 1, Valladolid': [-4.729, 41.65258],
        'Paseo Zorrilla, Valladolid': [-4.73869, 41.63817],
        '1900 amphitheatre parkway': [-122.0879468, 37.4234763],
        '1901 amphitheatre parkway': [-122.0879253, 37.4238725],
        '1902 amphitheatre parkway': [-122.0879531, 37.4234775],
        'Valladolid': [-4.73214, 41.6542],
        'Valladolid, Spain': [-4.73214, 41.6542],
        'Valladolid, Mexico': [-88.20117, 20.69021],
        'Madrid': [-3.70578, 40.42028],
        'Logroño, Spain': [-2.45194, 42.46592],
        'Logroño, Argentina': [-61.69604, -29.50425],
        'Plaza España, Barcelona': [2.14834, 41.37494]
    }

    TOMTOM_POINTS = HERE_POINTS.copy()
    TOMTOM_POINTS.update({
        'Plaza Mayor 1, Valladolid': [-4.7286, 41.6523],
        'Paseo Zorrilla, Valladolid': [-4.74031, 41.63181],
        'Valladolid': [-4.72838, 41.6542],
        'Valladolid, Spain': [-4.72838, 41.6542],
        'Madrid': [-3.70035, 40.42028],
        'Logroño, Spain': [-2.44998, 42.46592],
        'Plaza España, Barcelona': [2.14856, 41.37516]
    })

    MAPBOX_POINTS = GOOGLE_POINTS.copy()
    MAPBOX_POINTS.update({
        'Logroño, Spain': [-2.44556, 42.47],
        'Logroño, Argentina': [-70.687195, -33.470901],  # TODO: huge mismatch
        'Valladolid': [-4.72856, 41.652251],
        'Valladolid, Spain': [-4.72856, 41.652251],
        '1902 amphitheatre parkway': [-118.03, 34.06],  # TODO: huge mismatch
        'Madrid': [-3.69194, 40.4167754],
        'Plaza España, Barcelona': [2.342231, 41.50677]  # TODO: not ideal
    })

    FIXTURE_POINTS = {
        'google': GOOGLE_POINTS,
        'heremaps': HERE_POINTS,
        'tomtom': TOMTOM_POINTS,
        'mapbox': MAPBOX_POINTS
    }

    GOOGLE_METADATAS = {
        'Plaza España, Barcelona':
            {'relevance': 0.9, 'precision': 'precise', 'match_types': ['point_of_interest']},
        'Santiago Rusiñol 123, Valladolid':
            {'relevance': 0.56, 'precision': 'interpolated', 'match_types': ['locality']}
    }

    HERE_METADATAS = {
        'Plaza España, Barcelona':
            {'relevance': 1, 'precision': 'precise', 'match_types': ['street']},
        'Santiago Rusiñol 123, Valladolid':
            {'relevance': 0.89, 'precision': 'precise', 'match_types': ['street']}  # Wrong. See https://stackoverflow.com/questions/51285622/missing-matchtype-at-here-geocoding-responses
    }

    TOMTOM_METADATAS = {
        'Plaza España, Barcelona':
            {'relevance': 0.72, 'precision': 'precise', 'match_types': ['street']},
        'Santiago Rusiñol 123, Valladolid':
            {'relevance': 0.74, 'precision': 'precise', 'match_types': ['street']}
    }

    MAPBOX_METADATAS = {
        'Plaza España, Barcelona':
            {'relevance': 0.67, 'precision': 'precise', 'match_types': ['point_of_interest']},
        'Santiago Rusiñol 123, Valladolid':
            {'relevance': 0.67, 'precision': 'precise', 'match_types': ['point_of_interest']} # TODO: wrong
    }

    METADATAS = {
        'google': GOOGLE_METADATAS,
        'heremaps': HERE_METADATAS,
        'tomtom': TOMTOM_METADATAS,
        'mapbox': MAPBOX_METADATAS
    }

    def setUp(self):
        self.env_variables = IntegrationTestHelper.get_environment_variables()
        self.sql_api_url = "{0}://{1}.{2}/api/v1/sql".format(
            self.env_variables['schema'],
            self.env_variables['username'],
            self.env_variables['host'],
        )

        if not self.fixture_points:
            query = "select provider from " \
                    "cdb_dataservices_client.cdb_service_quota_info() " \
                    "where service = 'hires_geocoder'"
            response = self._run_authenticated(query)
            provider = response['rows'][0]['provider']
            self.fixture_points = self.FIXTURE_POINTS[provider]

            self.metadata = self.METADATAS[provider]

    def _run_authenticated(self, query):
        authenticated_query = "{}&api_key={}".format(query,
                                                     self.env_variables[
                                                         'api_key'])
        return IntegrationTestHelper.execute_query_raw(self.sql_api_url,
                                                       authenticated_query)

    def _used_quota(self):
        query = "select used_quota " \
                "from cdb_dataservices_client.cdb_service_quota_info() " \
                "where service = 'hires_geocoder'"
        return self._run_authenticated(query)['rows'][0]['used_quota']


class TestStreetFunctions(TestStreetFunctionsSetUp):

    def test_if_select_with_street_point_is_ok(self):
        query = "SELECT cdb_dataservices_client.cdb_geocode_street_point(street) " \
                "as geometry FROM {0} LIMIT 1&api_key={1}".format(
            self.env_variables['table_name'],
            self.env_variables['api_key'])
        geometry = IntegrationTestHelper.execute_query(self.sql_api_url, query)
        assert_not_equal(geometry['geometry'], None)

    def test_if_select_with_street_without_api_key_raise_error(self):
        table = self.env_variables['table_name']
        query = "SELECT cdb_dataservices_client.cdb_geocode_street_point(street) " \
                "as geometry FROM {0} LIMIT 1".format(table)
        try:
            self._run_authenticated(query)['rows'][0]
        except Exception as e:
            assert_equal(e, "permission denied for relation {}".format(table))

    def test_component_aggregation(self):
        query = "select st_x(the_geom), st_y(the_geom) from (" \
                "select cdb_dataservices_client.cdb_geocode_street_point( " \
                "'Plaza España', 'Barcelona', null, 'Spain') as the_geom) _x"
        response = self._run_authenticated(query)
        row = response['rows'][0]
        x_y = [row['st_x'], row['st_y']]
        # Wrong coordinates (Plaza España, Madrid): [-3.7138975, 40.4256762]
        assert_close_enough(x_y, self.fixture_points['Plaza España, Barcelona'])

class TestBulkStreetFunctions(TestStreetFunctionsSetUp):

    def test_full_spec(self):
        query = "select cartodb_id, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point(" \
                "'select 1 as cartodb_id, ''Spain'' as country, " \
                "''Castilla y León'' as state, ''Valladolid'' as city, " \
                "''Plaza Mayor 1'' as street  " \
                "UNION " \
                "select 2 as cartodb_id, ''Spain'' as country, " \
                "''Castilla y León'' as state, ''Valladolid'' as city, " \
                "''Paseo Zorrilla'' as street' " \
                ", 'street', 'city', 'state', 'country')"
        response = self._run_authenticated(query)

        points_by_cartodb_id = {
            1: self.fixture_points['Plaza Mayor 1, Valladolid'],
            2: self.fixture_points['Paseo Zorrilla, Valladolid']
        }
        self.assert_close_points(self._x_y_by_cartodb_id(response), points_by_cartodb_id)

    def test_empty_columns(self):
        query = "select *, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point( " \
                "'select * from jsonb_to_recordset(''[" \
                "{\"cartodb_id\": 1, \"address\": \"1901 amphitheatre parkway, mountain view, ca, us\"}" \
                "]''::jsonb) as (cartodb_id integer, address text)', " \
                "'address', '''''', '''''', '''''')"
        response = self._run_authenticated(query)

        assert_close_enough(self._x_y_by_cartodb_id(response)[1],
                     self.fixture_points['1901 amphitheatre parkway'])

    def test_null_columns(self):
        query = "select *, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point( " \
                "'select * from jsonb_to_recordset(''[" \
                "{\"cartodb_id\": 1, \"address\": \"1901 amphitheatre parkway, mountain view, ca, us\"}" \
                "]''::jsonb) as (cartodb_id integer, address text)', " \
                "'address')"
        response = self._run_authenticated(query)

        assert_close_enough(self._x_y_by_cartodb_id(response)[1],
                     self.fixture_points['1901 amphitheatre parkway'])

    def test_batching(self):
        query = "select *, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point( " \
                "'select * from jsonb_to_recordset(''[" \
                "{\"cartodb_id\": 1, \"address\": \"1900 amphitheatre parkway, mountain view, ca, us\"}," \
                "{\"cartodb_id\": 2, \"address\": \"1901 amphitheatre parkway, mountain view, ca, us\"}," \
                "{\"cartodb_id\": 3, \"address\": \"1902 amphitheatre parkway, mountain view, ca, us\"}" \
                "]''::jsonb) as (cartodb_id integer, address text)', " \
                "'address', null, null, null, 2)"
        response = self._run_authenticated(query)

        points_by_cartodb_id = {
            1: self.fixture_points['1900 amphitheatre parkway'],
            2: self.fixture_points['1901 amphitheatre parkway'],
            3: self.fixture_points['1902 amphitheatre parkway'],
        }
        self.assert_close_points(self._x_y_by_cartodb_id(response), points_by_cartodb_id)

    def test_batch_size_1(self):
        query = "select *, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point( " \
                "'select * from jsonb_to_recordset(''[" \
                "{\"cartodb_id\": 1, \"address\": \"1900 amphitheatre parkway, mountain view, ca, us\"}," \
                "{\"cartodb_id\": 2, \"address\": \"1901 amphitheatre parkway, mountain view, ca, us\"}," \
                "{\"cartodb_id\": 3, \"address\": \"1902 amphitheatre parkway, mountain view, ca, us\"}" \
                "]''::jsonb) as (cartodb_id integer, address text)', " \
                "'address', null, null, null, 1)"
        response = self._run_authenticated(query)

        points_by_cartodb_id = {
            1: self.fixture_points['1900 amphitheatre parkway'],
            2: self.fixture_points['1901 amphitheatre parkway'],
            3: self.fixture_points['1902 amphitheatre parkway'],
        }
        self.assert_close_points(self._x_y_by_cartodb_id(response), points_by_cartodb_id)

    def test_city_column_geocoding(self):
        query = "select *, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point( " \
                "'select * from jsonb_to_recordset(''[" \
                "{\"cartodb_id\": 1, \"city\": \"Valladolid\"}," \
                "{\"cartodb_id\": 2, \"city\": \"Madrid\"}" \
                "]''::jsonb) as (cartodb_id integer, city text)', " \
                "'city')"
        response = self._run_authenticated(query)

        assert_equal(response['total_rows'], 2)

        points_by_cartodb_id = {
            1: self.fixture_points['Valladolid'],
            2: self.fixture_points['Madrid']
        }
        self.assert_close_points(self._x_y_by_cartodb_id(response), points_by_cartodb_id)

    def test_free_text_geocoding(self):
        query = "select *, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point( " \
                "'select * from (" \
                "select 1 as cartodb_id, ''W 26th Street'' as address, " \
                "null as city , null as state , null as country" \
                ")_x', " \
                "'''Logroño, La Rioja, Spain''')"
        response = self._run_authenticated(query)

        assert_close_enough(self._x_y_by_cartodb_id(response)[1],
                     self.fixture_points['Logroño, Spain'])

    def test_templating_geocoding(self):
        query = "SELECT cartodb_id, st_x(the_geom), st_y(the_geom) from " \
                "cdb_dataservices_client.cdb_bulk_geocode_street_point(" \
                "'select 1 as cartodb_id, ''Logroño'' as city', " \
                "'city || '', '' || ''Spain''') " \
                "UNION " \
                "SELECT cartodb_id, st_x(the_geom), st_y(the_geom) from " \
                "cdb_dataservices_client.cdb_bulk_geocode_street_point(" \
                "'select 2 as cartodb_id, ''Logroño'' as city', " \
                "'city || '', '' || ''Argentina''')"
        response = self._run_authenticated(query)

        points_by_cartodb_id = {
            1: self.fixture_points['Logroño, Spain'],
            2: self.fixture_points['Logroño, Argentina']
        }
        self.assert_close_points(self._x_y_by_cartodb_id(response), points_by_cartodb_id)

    def test_template_with_two_columns_geocoding(self):
        query = "SELECT cartodb_id, st_x(the_geom), st_y(the_geom) from " \
                "cdb_dataservices_client.cdb_bulk_geocode_street_point(" \
                "    'select * from (' ||" \
                "    '  select 1 as cartodb_id, ''Valladolid'' as city, ''Mexico'' as country ' ||" \
                "    '  union all '  ||" \
                "    '  select 2, ''Valladolid'', ''Spain''' ||" \
                "    ') _x'," \
                "'city || '', '' || country')"
        response = self._run_authenticated(query)

        points_by_cartodb_id = {
            1: self.fixture_points['Valladolid, Mexico'],
            2: self.fixture_points['Valladolid, Spain']
        }
        self.assert_close_points(self._x_y_by_cartodb_id(response), points_by_cartodb_id)

    def test_large_batches(self):
        """
        Useful just to test a good batch size
        """
        n = 110
        first_cartodb_id = -1
        first_street_number = 1
        batch_size = 'NULL'  # NULL for optimal
        streets = []
        for i in range(0, n):
            streets.append('{{"cartodb_id": {}, "address": "{} Yonge Street, ' \
                           'Toronto, Canada"}}'.format(first_cartodb_id + i,
                                                       first_street_number + i))

        used_quota = self._used_quota()

        query = "select *, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point( " \
                "'select * from jsonb_to_recordset(''[" \
                "{}" \
                "]''::jsonb) as (cartodb_id integer, address text)', " \
                "'address', null, null, null, {})".format(','.join(streets), batch_size)
        response = self._run_authenticated(query, method='POST')
        assert_equal(n, len(response['rows']))
        for row in response['rows']:
            assert_not_equal(row['st_x'], None)
            assert_not_equal(row['metadata'], {})
            metadata = row['metadata']
            assert_not_equal(metadata['relevance'], None)
            assert_not_equal(metadata['precision'], None)
            assert_not_equal(metadata['match_types'], None)

        assert_equal(self._used_quota(), used_quota + n)

    def test_missing_components_on_private_function(self):
        query = "SELECT _cdb_bulk_geocode_street_point(" \
                "   '[{\"id\": \"1\", \"address\": \"Amphitheatre Parkway 22\"}]' " \
                ")"
        response = self._run_authenticated(query)
        assert_equal(1, len(response['rows']))

    def test_semicolon(self):
        query = "select *, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point( " \
                "'select * from jsonb_to_recordset(''[" \
                "{\"cartodb_id\": 1, \"address\": \"1900 amphitheatre parkway; mountain view; ca; us\"}," \
                "{\"cartodb_id\": 2, \"address\": \"1900 amphitheatre parkway, mountain view, ca, us\"}" \
                "]''::jsonb) as (cartodb_id integer, address text)', " \
                "'address', null, null, null)"
        response = self._run_authenticated(query)

        x_y_by_cartodb_id = self._x_y_by_cartodb_id(response)
        assert_equal(x_y_by_cartodb_id[1], x_y_by_cartodb_id[2])

    def test_component_aggregation(self):
        query = "select cartodb_id, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point(" \
                "'select 1 as cartodb_id, ''Spain'' as country, " \
                "''Barcelona'' as city, " \
                "''Plaza España'' as street' " \
                ", 'street', 'city', NULL, 'country')"
        response = self._run_authenticated(query)

        assert_close_enough(self._x_y_by_cartodb_id(response)[1],
                            self.fixture_points['Plaza España, Barcelona'])

    def _test_known_table(self):
        subquery = 'select * from unknown_table where cartodb_id < 1100'
        subquery_count = 'select count(1) from ({}) _x'.format(subquery)
        count = self._run_authenticated(subquery_count)['rows'][0]['count']

        query = "select cartodb_id, st_x(the_geom), st_y(the_geom) " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point(" \
                "'{}' " \
                ", 'street', 'city', NULL, 'country')".format(subquery)
        response = self._run_authenticated(query)
        assert_equal(len(response['rows']), count)
        assert_not_equal(response['rows'][0]['st_x'], None)

    def test_metadata(self):
        query = "select metadata " \
                "FROM cdb_dataservices_client.cdb_bulk_geocode_street_point(" \
                "'select 1 as cartodb_id, ''Spain'' as country, " \
                "''Barcelona'' as city, " \
                "''Plaza España'' as street " \
                "UNION " \
                "select 2 as cartodb_id, ''Spain'' as country, " \
                "''Valladolid'' as city, " \
                "''Santiago Rusiñol 123'' as street' " \
                ", 'street', 'city', NULL, 'country')"
        response = self._run_authenticated(query)

        expected = [
            self.metadata['Plaza España, Barcelona'],
            self.metadata['Santiago Rusiñol 123, Valladolid']
        ]
        assert_equal(len(response['rows']), len(expected))
        for r, e in zip(response['rows'], expected):
            self.assert_metadata(r['metadata'], e)

    def _run_authenticated(self, query, method='GET'):
        api_key = self.env_variables['api_key']
        url = self.sql_api_url
        auth_query = "{}&api_key={}".format(query, api_key)
        if method.upper() != 'GET':
            auth_query = query
            url = "{}?api_key={}".format(self.sql_api_url, api_key)
        return IntegrationTestHelper.execute_query_raw(url, auth_query, method)

    @staticmethod
    def _x_y_by_cartodb_id(response):
        return {r['cartodb_id']: [r['st_x'], r['st_y']]
                for r in response['rows']}

    @staticmethod
    def assert_close_points(points_a_by_cartodb_id, points_b_by_cartodb_id):
        assert_equal(len(points_a_by_cartodb_id), len(points_b_by_cartodb_id))
        for cartodb_id, point in points_a_by_cartodb_id.iteritems():
            assert_close_enough(point, points_b_by_cartodb_id[cartodb_id])

    @staticmethod
    def assert_metadata(metadata, expected):
        relevance = metadata['relevance']
        expected_relevance = expected['relevance']
        assert_true(isclose(relevance, expected_relevance, 0.02),
                    '{} not close to {}'.format(relevance, expected_relevance))

        assert_equal(metadata['precision'], expected['precision'])

        assert_equal(metadata['match_types'], expected['match_types'])
