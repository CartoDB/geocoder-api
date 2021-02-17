import unittest
from mock import Mock
from cartodb_services.geocoder import (GeocoderProxy, FirstAvailableGeocoder,
                                       CheapestGeocoder)
from cartodb_services.geocoder.types import MAPBOX, GOOGLE, HERE


class GeocoderProxyTestCase(unittest.TestCase):
    def setUp(self):
        pass

    def test_firstavailable(self):
        available_geocoders = [MAPBOX]
        geocoder_proxy = GeocoderProxy(FirstAvailableGeocoder(
            available_geocoders), dbconn=Mock(), logger=Mock())
        self.assertEqual(geocoder_proxy._geocoder_name, MAPBOX)

        available_geocoders = [GOOGLE, MAPBOX, HERE]
        geocoder_proxy = GeocoderProxy(FirstAvailableGeocoder(
            available_geocoders), dbconn=Mock(), logger=Mock())
        self.assertEqual(geocoder_proxy._geocoder_name, GOOGLE)

    def test_cheapest(self):
        available_geocoders = [MAPBOX]
        geocoder_proxy = GeocoderProxy(CheapestGeocoder(
            available_geocoders), dbconn=Mock(), logger=Mock())
        self.assertEqual(geocoder_proxy._geocoder_name, MAPBOX)

        available_geocoders = [GOOGLE, MAPBOX, HERE]
        geocoder_proxy = GeocoderProxy(CheapestGeocoder(
            available_geocoders), dbconn=Mock(), logger=Mock())
        self.assertEqual(geocoder_proxy._geocoder_name, MAPBOX)

        available_geocoders = [GOOGLE, HERE]
        geocoder_proxy = GeocoderProxy(CheapestGeocoder(
            available_geocoders), dbconn=Mock(), logger=Mock())
        self.assertEqual(geocoder_proxy._geocoder_name, GOOGLE)

        available_geocoders = ['non_existing1', 'non_existing2']
        geocoder_proxy = GeocoderProxy(CheapestGeocoder(
            available_geocoders), dbconn=Mock(), logger=Mock())
        self.assertEqual(geocoder_proxy._geocoder_name, None)
