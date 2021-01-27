#!/usr/local/bin/python
# -*- coding: utf-8 -*-

import json
import requests
from uritemplate import URITemplate
from math import tanh
from cartodb_services.geocoder import PRECISION_PRECISE, PRECISION_INTERPOLATED, geocoder_metadata, EMPTY_RESPONSE, geocoder_error_response
from cartodb_services.metrics import Traceable
from cartodb_services.tools.exceptions import ServiceException
from cartodb_services.tools.qps import qps_retry
from cartodb_services.tools.normalize import normalize
from cartodb_services.tools.country import country_to_iso3

HOST = 'https://api.tomtom.com'
API_BASEURI = '/search/2'
REQUEST_BASEURI = ('/geocode/'
               '{searchtext}.json'
               '?limit=1')
ENTRY_RESULTS = 'results'
ENTRY_POSITION = 'position'
ENTRY_LON = 'lon'
ENTRY_LAT = 'lat'

SCORE_NORMALIZATION_FACTOR = 0.15
PRECISION_SCORE_THRESHOLD = 0.5
MATCH_TYPE_BY_MATCH_LEVEL = {
    'POI': 'point_of_interest',
    'Street': 'street',
    'Address Range': 'street',
    'Cross Street': 'intersection',
    'Point Address': 'street_number'
}

class TomTomGeocoder(Traceable):
    '''
    Python wrapper for the TomTom Geocoder service.
    '''

    def __init__(self, apikey, logger, service_params=None):
        service_params = service_params or {}
        self._apikey = apikey
        self._logger = logger

    def _uri(self, searchtext, country=None):
        return HOST + API_BASEURI + \
               self._request_uri(searchtext, country, self._apikey)

    def _request_uri(self, searchtext, country=None, apiKey=None):
        baseuri = REQUEST_BASEURI
        if country:
            baseuri += '&countrySet={}'.format(country_to_iso3(country) or country)
        baseuri = baseuri + '&key={apiKey}' if apiKey else baseuri
        return URITemplate(baseuri).expand(apiKey=apiKey,
                                           searchtext=searchtext.encode('utf-8'))

    def _extract_lng_lat_from_feature(self, result):
        position = result[ENTRY_POSITION]
        longitude = position[ENTRY_LON]
        latitude = position[ENTRY_LAT]
        return [longitude, latitude]

    def _validate_input(self, searchtext, city=None, state_province=None,
                        country=None):
        if searchtext and searchtext.strip():
            return True
        elif city:
            return True
        elif state_province:
            return True

        return False

    @qps_retry(qps=5, provider='tomtom')
    def geocode(self, searchtext, city=None, state_province=None,
                country=None):
        geocoder_response, http_response = self._geocode_meta(searchtext, city, state_province, country)
        error_message = geocoder_response[1].get('error', None)
        if error_message:
            raise ServiceException(error_message, http_response)
        else:
            return geocoder_response[0]

    def geocode_meta(self, searchtext, city=None, state_province=None,
                country=None):
        return self._geocode_meta(searchtext, city, state_province, country)[0]

    @qps_retry(qps=5, provider='tomtom')
    def _geocode_meta(self, searchtext, city=None, state_province=None,
                country=None):
        if searchtext:
            searchtext = searchtext.decode('utf-8')
        if city:
            city = city.decode('utf-8')
        if state_province:
            state_province = state_province.decode('utf-8')
        if country:
            country = country.decode('utf-8')

        if not self._validate_input(searchtext, city, state_province, country):
            return (EMPTY_RESPONSE, None)

        address = []
        if searchtext and searchtext.strip():
            address.append(normalize(searchtext))
        if city:
            address.append(normalize(city))
        if state_province:
            address.append(normalize(state_province))

        uri = self._uri(searchtext=', '.join(address), country=country)

        try:
            response = requests.get(uri)
            return (self._parse_response(response.status_code, response.text), response)
        except requests.Timeout as te:
            # In case of timeout we want to stop the job because the server
            # could be down
            msg = 'Timeout connecting to TomTom geocoding server'
            self._logger.error(msg, te)
            return (geocoder_error_response(msg), None)
        except requests.ConnectionError as ce:
            # Don't raise the exception to continue with the geocoding job
            self._logger.error('Error connecting to TomTom geocoding server',
                               exception=ce)
            return (EMPTY_RESPONSE, None)

    def _parse_response(self, status_code, text):
        if status_code == requests.codes.ok:
            return self._parse_geocoder_response(text)
        elif status_code == requests.codes.bad_request:
            return EMPTY_RESPONSE
        elif status_code == requests.codes.unprocessable_entity:
            return EMPTY_RESPONSE
        else:
            msg = 'Unknown response {}: {}'.format(str(status_code), text)
            self._logger.warning('Error parsing TomTom geocoding response',
                                 data={'msg': msg})
            return geocoder_error_response(msg)

    def _parse_geocoder_response(self, response):
        json_response = json.loads(response) \
            if type(response) != dict else response

        if json_response and json_response[ENTRY_RESULTS]:
            result = json_response[ENTRY_RESULTS][0]
            return [
                self._extract_lng_lat_from_feature(result),
                self._extract_metadata_from_result(result)
            ]
        else:
            return EMPTY_RESPONSE

    def _extract_metadata_from_result(self, result):
        score = self._normalize_score(result['score'])
        match_type = MATCH_TYPE_BY_MATCH_LEVEL.get(result['type'], None)
        return geocoder_metadata(
            score,
            self._precision_from_score(score),
            [match_type] if match_type else []
        )

    def _normalize_score(self, score):
        return tanh(score * SCORE_NORMALIZATION_FACTOR)

    def _precision_from_score(self, score):
        return PRECISION_PRECISE \
            if score > PRECISION_SCORE_THRESHOLD else PRECISION_INTERPOLATED
