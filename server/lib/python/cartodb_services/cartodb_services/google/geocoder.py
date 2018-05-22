#!/usr/local/bin/python
# -*- coding: utf-8 -*-

import googlemaps
from urlparse import parse_qs

from exceptions import MalformedResult
from cartodb_services.google.exceptions import InvalidGoogleCredentials
from client_factory import GoogleMapsClientFactory

from multiprocessing import Pool, TimeoutError
import time
import os
import json

def async_geocoder(geocoder, searchtext):
    results = geocoder.geocode(address=searchtext['address'])
    if results:
        return [searchtext['id'], results]
    else:
        return []

class GoogleMapsGeocoder:
    """A Google Maps Geocoder wrapper for python"""

    def __init__(self, client_id, client_secret, logger):
        if client_id is None:
            self.client_id = None
            self.channel = None
        else:
            self.client_id, self.channel = self.parse_client_id(client_id)
        self.client_secret = client_secret
        self.geocoder = GoogleMapsClientFactory.get(self.client_id, self.client_secret, self.channel)
        self._logger = logger

    def geocode(self, searchtext, city=None, state=None,
                country=None):
        try:
            opt_params = self._build_optional_parameters(city, state, country)
            results = self.geocoder.geocode(address=searchtext,
                                            components=opt_params)
            if results:
                return self._extract_lng_lat_from_result(results[0])
            else:
                return []
        except KeyError:
            raise MalformedResult()

    def bulk_geocode(self, searchtext):
        pool = Pool(processes=13)
        bulk_results = []
        results = []
        decoded_searchtext = json.loads(searchtext)
        for search in decoded_searchtext:
            bulk_results.append(pool.apply_async(async_geocoder, (self.geocoder, search)))
        pool.close()
        pool.join()
        try:
            for bulk_result in bulk_results:
                result = bulk_result.get()
                results.append([result[0], self._extract_lng_lat_from_result(result[1][0]), []])
            return results
        except KeyError as e:
            raise MalformedResult()

    def _extract_lng_lat_from_result(self, result):
        location = result['geometry']['location']
        longitude = location['lng']
        latitude = location['lat']
        return [longitude, latitude]

    def _build_optional_parameters(self, city=None, state=None,
                                   country=None):
        optional_params = {}
        if city:
            optional_params['locality'] = city
        if state:
            optional_params['administrative_area'] = state
        if country:
            optional_params['country'] = country
        return optional_params

    def parse_client_id(self, client_id):
        arguments = parse_qs(client_id)
        client = arguments['client'][0] if arguments.has_key('client') else client_id
        channel = arguments['channel'][0] if arguments.has_key('channel') else None
        return client, channel
