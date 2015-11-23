#!/usr/local/bin/python
# -*- coding: utf-8 -*-

import json

class BadGeocodingParams(Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr('Bad geocoding params: ' + json.dumps(self.value))

class NoGeocodingParams(Exception):
    def __str__(self):
        return repr('No params for geocoding specified')

class MalformedResult(Exception):
  def __str__(self):
        return repr('Result structure is malformed')
