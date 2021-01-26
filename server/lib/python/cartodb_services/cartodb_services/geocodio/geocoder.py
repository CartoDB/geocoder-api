from geocodio import GeocodioClient
from geocodio.exceptions import GeocodioAuthError, GeocodioServerError, GeocodioDataError, GeocodioError

from cartodb_services.tools.qps import qps_retry
from cartodb_services.metrics import Traceable
from cartodb_services.geocoder import EMPTY_RESPONSE, geocoder_metadata
from cartodb_services.tools.exceptions import ServiceException


RELEVANCE_BY_LOCATION_TYPE = {
    'rooftop': 1,
    'point': 0.9,
    'range_interpolation': 0.8,
    'nearest_rooftop_match': 0.7,
    'intersection': 0.6,
    'street_center': 0.5,
    'place': 0.4,
    'state': 0.1,
}


class GeocodioGeocoder(Traceable):
    '''
    Python wrapper for the Geocodio Geocoder service.
    '''

    def __init__(self, token, logger, service_params=None):
        service_params = service_params or {}
        self._token = token
        self._logger = logger

        self._geocoder = GeocodioClient(self._token, hipaa_enabled=True)

    def _validate_input(self, searchtext, city=None, state_province=None,
                        country=None):
        if searchtext and searchtext.strip():
            return True
        elif city:
            return True
        elif state_province:
            return True

        return False

    @qps_retry(qps=15, provider='geocodio')
    def geocode(self, searchtext, city=None, state_province=None,
                country=None):
        return self._geocode_meta(searchtext, city, state_province, country)[0]

    def geocode_meta(self, searchtext, city=None, state_province=None,
                     country=None):
        return self._geocode_meta(searchtext, city, state_province, country)[0]

    @qps_retry(qps=15, provider='geocodio')
    def _geocode_meta(self, searchtext, city=None, state_province=None,
                      country=None):
        if not self._validate_input(searchtext, city, state_province, country):
            return EMPTY_RESPONSE

        try:
            free_text_components = [searchtext, city, state_province, country]
            req = '; '.join([c for c in free_text_components if c is not None and c.strip()])
            response = self._geocoder.geocode(req)

            return self._parse_geocoder_response(response)
        except GeocodioDataError as gde:
            return EMPTY_RESPONSE
        except GeocodioAuthError as gae:
            raise ServiceException('Geocodio authorization error: ' + str(gae), None)
        except GeocodioServerError as gse:
            raise ServiceException('geocodio server error: ' + str(gse), None)
        except GeocodioError as ge:
            raise ServiceException('Unknown Geocodio error: ' + str(ge), None)

    @qps_retry(qps=15)
    def geocode_free_text_meta(self, free_searches, country=None):
        """
        :param free_searches: Free text searches
        :return: list of [x, y] on success, [] on error
        """
        output = []

        try:
            if country:
                free_searches = ['{s}, {country}'.format(s, country) for s in free_searches]

            responses = self._geocoder.geocode(free_searches)

            for response in responses:
                output.append(self._parse_geocoder_response(response))
        except GeocodioDataError as gde:
            return EMPTY_RESPONSE
        except GeocodioAuthError as gae:
            raise ServiceException('Geocodio authorization error: ' + str(gae), None)
        except GeocodioServerError as gse:
            raise ServiceException('geocodio server error: ' + str(gse), None)
        except GeocodioError as ge:
            raise ServiceException('Unknown Geocodio error: ' + str(ge), None)

        return output

    def _parse_geocoder_response(self, response):
        if response is None or not response:
            return EMPTY_RESPONSE

        if response.get('results') is None or not response.get('results'):
            return EMPTY_RESPONSE

        if response.coords is None or not response.coords:
            return EMPTY_RESPONSE

        coords = [None, None]
        accuracy = None
        accuracy_type = None

        accuracy = response.accuracy

        if response.coords is not None and response.coords:
            coords = [response.coords[1], response.coords[0]]

        if response.get('results'):
            accuracy_type = response.get('results')[0].get('accuracy_type')

        metadata = geocoder_metadata(RELEVANCE_BY_LOCATION_TYPE.get(accuracy_type), response.accuracy, [accuracy_type])

        return [coords, metadata]
