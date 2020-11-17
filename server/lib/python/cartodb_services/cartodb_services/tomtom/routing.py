'''
Python client for the TomTom Routing service.
'''

import json
import requests
from uritemplate import URITemplate
from cartodb_services.metrics import Traceable
from cartodb_services.tools import PolyLine
from cartodb_services.tools.coordinates import (validate_coordinates,
                                                marshall_coordinates)
from cartodb_services.tools.exceptions import ServiceException
from cartodb_services.tools.qps import qps_retry
from types import (DEFAULT_PROFILE, DEFAULT_ROUTE_TYPE, VALID_PROFILES, VALID_ROUTE_TYPE, DEFAULT_DEPARTAT)

BASEURI = ('https://api.tomtom.com/routing/1/calculateRoute/'
           '{coordinates}'
           '/json'
           '?key={apikey}'
           '&travelMode={travelmode}'
           '&routeType={route_type}'
           '&departAt={departat}'
           '&computeBestOrder=true')

NUM_WAYPOINTS_MIN = 2
NUM_WAYPOINTS_MAX = 20

ENTRY_ROUTES = 'routes'
ENTRY_SUMMARY = 'summary'
ENTRY_LENGTH = 'lengthInMeters'
ENTRY_TIME = 'travelTimeInSeconds'
ENTRY_LEGS = 'legs'
ENTRY_POINTS = 'points'
ENTRY_LATITUDE = 'latitude'
ENTRY_LONGITUDE = 'longitude'


class TomTomRouting(Traceable):
    '''
    Python wrapper for the TomTom Routing service.
    '''

    def __init__(self, apikey, logger, service_params=None):
        service_params = service_params or {}
        self._apikey = apikey
        self._logger = logger

    def _uri(self, coordinates, profile=DEFAULT_PROFILE,
             date_time=DEFAULT_DEPARTAT, route_type=DEFAULT_ROUTE_TYPE):
        uri = URITemplate(BASEURI).expand(apikey=self._apikey,
                                          coordinates=coordinates,
                                          travelmode=profile,
                                          route_type=route_type,
                                          departat=date_time)
        return uri

    def _validate_profile(self, profile):
        if profile not in VALID_PROFILES:
            raise ValueError('{profile} is not a valid profile. '
                             'Valid profiles are: {valid_profiles}'.format(
                                 profile=profile,
                                 valid_profiles=', '.join(
                                     [x for x in VALID_PROFILES])))

    def _validate_route_type(self, route_type):
        if route_type not in VALID_ROUTE_TYPE:
            raise ValueError('{route_type} is not a valid route type. '
                             'Valid route types are: {valid_route_types}'.format(
                                 route_type=route_type,
                                 valid_route_types=', '.join(
                                     [x for x in VALID_ROUTE_TYPE])))

    def _marshall_coordinates(self, coordinates):
        return ':'.join(['{lat},{lon}'.format(lat=coordinate.latitude,
                                              lon=coordinate.longitude)
                         for coordinate in coordinates])

    def _parse_routing_response(self, response):
        json_response = json.loads(response)

        if json_response:
            route = json_response[ENTRY_ROUTES][0]  # Force the first route

            geometry = self._parse_legs(route[ENTRY_LEGS])
            summary = route[ENTRY_SUMMARY]
            distance = summary[ENTRY_LENGTH]
            duration = summary[ENTRY_TIME]

            return TomTomRoutingResponse(geometry, distance, duration)
        else:
            return TomTomRoutingResponse(None, None, None)

    def _parse_legs(self, legs):
        geometry = []
        for leg in legs:
            points = leg[ENTRY_POINTS]
            for point in points:
                geometry.append((point[ENTRY_LATITUDE],
                                 point[ENTRY_LONGITUDE]))
        return geometry

    @qps_retry(qps=5, provider='tomtom')
    def directions(self, waypoints, profile=DEFAULT_PROFILE,
                   date_time=DEFAULT_DEPARTAT, route_type=DEFAULT_ROUTE_TYPE):
        self._validate_profile(profile)
        self._validate_route_type(route_type)
        validate_coordinates(waypoints, NUM_WAYPOINTS_MIN, NUM_WAYPOINTS_MAX)

        coordinates = self._marshall_coordinates(waypoints)

        uri = self._uri(coordinates, profile, date_time, route_type)

        try:
            response = requests.get(uri)

            if response.status_code == requests.codes.ok:
                return self._parse_routing_response(response.text)
            elif response.status_code == requests.codes.bad_request:
                return TomTomRoutingResponse(None, None, None)
            elif response.status_code == requests.codes.unprocessable_entity:
                return TomTomRoutingResponse(None, None, None)
            else:
                raise ServiceException('Unexpected response (' + str(response.status_code) + '): ' + str(response.content), response)
        except requests.Timeout as te:
            # In case of timeout we want to stop the job because the server
            # could be down
            self._logger.error('Timeout connecting to TomTom routing service',
                               te)
            raise ServiceException('Error getting routing data from TomTom',
                                   None)
        except requests.ConnectionError as ce:
            # Don't raise the exception to continue with the geocoding job
            self._logger.error('Error connecting to TomTom routing service',
                               exception=ce)
            return TomTomRoutingResponse(None, None, None)


class TomTomRoutingResponse:

    def __init__(self, shape, length, duration):
        self._shape = shape
        self._length = length
        self._duration = duration

    @property
    def shape(self):
        return self._shape

    @property
    def length(self):
        return self._length

    @property
    def duration(self):
        return self._duration
