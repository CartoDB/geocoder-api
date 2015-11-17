#!/usr/local/bin/python
# -*- coding: utf-8 -*-

import json
import urllib

from heremaps.heremapsexceptions import BadGeocodingParams
from heremaps.heremapsexceptions import NoGeocodingParams
from heremaps.heremapsexceptions import MalformedResult

class Geocoder:
    'A Here Maps Geocoder wrapper for python'

    URL_GEOCODE_JSON = 'http://geocoder.api.here.com/6.2/geocode.json'
    DEFAULT_MAXRESULTS = 1
    DEFAULT_GEN = 9

    ADDRESS_PARAMS = [
        'city',
        'country',
        'county',
        'district',
        'housenumber',
        'postalcode',
        'searchtext',
        'state',
        'street'
        ]

    ADMITTED_PARAMS = [
        'additionaldata',
        'app_id',
        'app_code',
        'bbox',
        'countryfocus',
        'gen',
        'jsonattributes',
        'jsoncallback',
        'language',
        'locationattributes',
        'locationid',
        'mapview',
        'maxresults',
        'pageinformation',
        'politicalview',
        'prox',
        'strictlanguagemode'
        ] + ADDRESS_PARAMS

    app_id = ''
    app_code = ''
    maxresults = ''

    def __init__(self, app_id, app_code, maxresults=DEFAULT_MAXRESULTS, gen=DEFAULT_GEN):
        self.app_id = app_id
        self.app_code = app_code
        self.maxresults = maxresults
        self.gen = gen

    def geocode(self, params):
        if not set(params.keys()).issubset(set(self.ADDRESS_PARAMS)):
            raise BadGeocodingParams(params)

        response = self.perform_request(params)

        try:
            results = response['Response']['View'][0]['Result']
        except IndexError:
            raise MalformedResult()

        return results if results else None

    def perform_request(self, params):
        request_params = {
            'app_id' : self.app_id,
            'app_code' : self.app_code,
            'maxresults' : self.maxresults,
            'gen' : self.gen
            }
        request_params.update(params)

        encoded_request_params = urllib.urlencode(request_params)

        response = json.load(
            urllib.urlopen(self.URL_GEOCODE_JSON
                + '?'
                + encoded_request_params))

        return response

    def geocode_address(self, **kwargs):
        params = {}
        for key, value in kwargs.iteritems():
            if value: params[key] = value

        if not params: raise NoGeocodingParams()

        return self.geocode(params)

    def extract_lng_lat_from_result(self, result):
        try:
            location = result['Location']

            longitude = location['DisplayPosition']['Longitude']
            latitude = location['DisplayPosition']['Latitude']
        except KeyError:
            raise MalformedResult()

        return [longitude, latitude]
