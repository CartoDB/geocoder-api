import rollbar
import logging
import traceback
import sys
from cartodb_services.config.server_config import ServerConfigFactory
# Monkey patch because plpython sys module doesn't have argv and rollbar
# package use it
sys.__dict__['argv'] = []

try:
    import plpy
except ImportError:
    pass

class Logger:

    LEVELS = {'debug': 1, 'info': 2, 'warning': 3, 'error': 4}

    def __init__(self, config):
        self._config = config
        self._min_level = self.LEVELS[self._config.min_log_level]
        # We need to set the handler blocking (synchronous) because
        # spawn a thread from plpython interpreter don't work
        if self._rollbar_activated():
            rollbar.init(self._config.rollbar_api_key,
                        self._config.environment, handler='blocking')
        if self._log_file_activated():
            self._file_logger = self._setup_file_logger(
                self._config.log_file_path)

    def debug(self, text, exception=None, data={}):
        if not self._check_min_level('debug'):
            return
        self._send_to_rollbar('debug', text, exception, data)
        self._send_to_log_file('debug', text, exception, data)
        self._send_to_plpy('debug', text)

    def info(self, text, exception=None, data={}):
        if not self._check_min_level('info'):
            return
        self._send_to_rollbar('info', text, exception, data)
        self._send_to_log_file('info', text, exception, data)
        self._send_to_plpy('info', text)

    def warning(self, text, exception=None, data={}):
        if not self._check_min_level('warning'):
            return
        self._send_to_rollbar('warning', text, exception, data)
        self._send_to_log_file('warning', text, exception, data)
        self._send_to_plpy('warning', text)

    def error(self, text, exception=None, data={}):
        if not self._check_min_level('error'):
            return
        self._send_to_rollbar('error', text, exception, data)
        self._send_to_log_file('error', text, exception, data)
        # Plpy.error and fatal raises exceptions and we only want to log an
        # error, exceptions should be raise explicitly
        self._send_to_plpy('error', text)

    def _check_min_level(self, level):
        return True if self.LEVELS[level] >= self._min_level else False

    def _send_to_rollbar(self, level, text, exception, data):
        if self._rollbar_activated():
            try:
                if exception:
                    rollbar.report_exc_info(exception, extra_data=data,
                                            level=level)
                else:
                    rollbar.report_message(text, level, extra_data=data)
            except Exception as e:
                plpy.warning('Error sending message/exception to rollbar: {0}'.
                             format(e))

    def _send_to_log_file(self, level, text, exception, data):
        if self._log_file_activated():
            extra_data = self._parse_log_extra_data(exception, data)
            if level == 'debug':
                self._file_logger.debug(text, extra=extra_data)
            elif level == 'info':
                self._file_logger.info(text, extra=extra_data)
            elif level == 'warning':
                self._file_logger.warning(text, extra=extra_data)
            elif level == 'error':
                self._file_logger.error(text, extra=extra_data)

    def _send_to_plpy(self, level, text):
        if self._check_plpy():
            if level == 'debug':
                plpy.debug(text)
            elif level == 'info':
                plpy.info(text)
            elif level == 'warning':
                plpy.warning(text)
            elif level == 'error':
                # Plpy.error and fatal raises exceptions and we only want to
                # log an error, exceptions should be raise explicitly
                plpy.warning(text)

    def _parse_log_extra_data(self, exception, data):
        extra_data = {}
        if exception:
            type_, value_, traceback_ = exception
            exception_traceback = traceback.format_tb(traceback_)
            extra_data = {"exception_type": type_, "exception_message": value_,
                          "exception_traceback": exception_traceback,
                          "log_data": data}
        else:
            extra_data = {"exception_type": '', "exception_message": '',
                          "exception_traceback": '', 'log_data': ''}

        if data:
            extra_data['data'] = data
        else:
            extra_data['data'] = ''

        return extra_data

    def _setup_file_logger(self, log_file_path):
        logging.basicConfig(level='DEBUG')
        formatter = logging.Formatter("%(asctime)s %(name)-12s %(levelname)-8s %(message)s %(data)s %(exception_type)s %(exception_message)s %(exception_traceback)s")
        logger = logging.getLogger('dataservices_file_logger')
        handler = logging.FileHandler(log_file_path)
        handler.setFormatter(formatter)
        handler.setLevel(self._config.min_log_level.upper())
        logger.addHandler(handler)

        return logger

    def _rollbar_activated(self):
        return True if self._config.rollbar_api_key else False

    def _log_file_activated(self):
        return True if self._config.log_file_path else False

    def _check_plpy(self):
        try:
            module = sys.modules['plpy']
            return True
        except KeyError:
            return False


class ConfigException(Exception):
    pass


class LoggerConfig:

    def __init__(self):
        self._server_config = ServerConfigFactory.get()
        return self._build()

    def _build(self):
        self._get_server_config()
        self._get_logger_config()

    def _get_server_config(self):
        server_config = self._server_config.get('server_conf')
        if not server_config:
            self._server_environment = 'development'
        else:
            if 'environment' in server_config:
                self._server_environment = server_config['environment']
            else:
                self._server_environment = 'development'

    def _get_logger_config(self):
        logger_conf = self._server_config.get('logger_conf')
        if not logger_conf:
            raise ConfigException('Logger configuration missing')
        else:
            self._rollbar_api_key = None
            self._min_log_level = 'warning'
            self._log_file_path = None
            if 'min_log_level' in logger_conf:
                self._min_log_level = logger_conf['min_log_level']
            if 'rollbar_api_key' in logger_conf:
                self._rollbar_api_key = logger_conf['rollbar_api_key']
            if 'log_file_path' in logger_conf:
                self._log_file_path = logger_conf['log_file_path']

    @property
    def environment(self):
        return self._server_environment

    @property
    def rollbar_api_key(self):
        return self._rollbar_api_key

    @property
    def log_file_path(self):
        return self._log_file_path

    @property
    def min_log_level(self):
        return self._min_log_level
