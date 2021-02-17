from types import MAPBOX

CACHEABLE_GEOCODERS = [MAPBOX]

SELECT_CACHE = ("select response from geocode_cache_{provider} "
                "where id = '{id}'")
INSERT_CACHE = ("insert into geocode_cache_{provider} "
                "(id, searchtext, city, state_province, country, response) "
                "values  (%s, %s, %s, %s, %s, %s) ")


def is_geocoder_cacheable(geocoder_name):
    return geocoder_name in CACHEABLE_GEOCODERS


class CacheableGeocoder:
    def __init__(self, geocoder, dbconn, use_cache=True, save_cache=True):
        self._geocoder = geocoder
        self._dbconn = dbconn
        self._use_cache = use_cache
        self._save_cache = save_cache

    def geocode(self, searchtext, city=None, state_province=None,
                country=None):
        response = None
        if self._use_cache and is_geocoder_cacheable(self._geocoder.name):
            response = self._find_in_cache(searchtext, city, state_province,
                                           country)

        if not response:
            response = self._lookup_geocoder(searchtext, city, state_province,
                                             country)

        return self._geocoder.format_response(response)

    def _find_in_cache(self, searchtext, city=None, state_province=None,
                       country=None):
        normalized_address = self._normalize_address(searchtext, city,
                                                     state_province, country)
        with self._dbconn.cursor() as cursor:
            cursor.execute(SELECT_CACHE.format(provider=self._geocoder.name,
                                               id=normalized_address))
            data = cursor.fetchone()
            return data[0] if data else None

        return None

    def _save_to_cache(self, response, searchtext, city=None,
                       state_province=None, country=None):
        normalized_address = self._normalize_address(searchtext, city,
                                                     state_province, country)
        response = response.encode('utf-8')  # https://github.com/requests/requests/issues/1604

        with self._dbconn.cursor() as cursor:
            cursor.execute(INSERT_CACHE.format(provider=self._geocoder.name),
                           (normalized_address, searchtext, city,
                            state_province, country, response))
            self._dbconn.commit()

    def _lookup_geocoder(self, searchtext, city=None, state_province=None,
                         country=None):
        response = self._geocoder.geocode(searchtext, city, state_province,
                                          country)

        if self._save_cache and is_geocoder_cacheable(self._geocoder.name):
            self._save_to_cache(response, searchtext, city, state_province,
                                country)

        return response

    def _normalize_address(self, searchtext, city=None, state_province=None,
                           country=None):
        if searchtext and searchtext.strip():
            address = [searchtext]
            if city:
                address.append(city)
            if state_province:
                address.append(state_province)
            if country:
                address.append(country)

            address = ', '.join(address)

            return ' '.join(address.replace(',', ' ').split()).replace(' ', '_')

        return None
