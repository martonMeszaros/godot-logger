extends Node

const Constants := preload("constants.gd")
const ExternalSink := preload("external_sink.gd")
const ExternalSinkFactory := preload("external_sink_factory.gd")
const LogFile := preload("logfile.gd")
const Logger := preload("logger.gd")


var default_output_level: int setget set_default_output_level
var default_output_strategies: Array setget set_default_output_strategies
var default_output_format: String setget set_default_output_format
var default_time_format: String setget set_default_time_format
var default_filepath_time_format: String
var default_logfile_path: String setget set_default_logfile_path
var _external_sinks: Dictionary
var _loggers: Dictionary
var _built_in: Logger
var _default: Logger


func _init() -> void:
	default_output_level = Constants.Level.INFO
	default_output_strategies = [
		Constants.Strategy.PRINT,
		Constants.Strategy.PRINT,
		Constants.Strategy.PRINT,
		Constants.Strategy.PRINT,
		Constants.Strategy.PRINT,
	]
	default_output_format = "[{TIME}] [{LVL}] [{MOD}]{ERR_MSG} {MSG}"
	default_time_format = "hh:mm:ss"
	default_filepath_time_format = "YYYY-MM-DD"
	default_logfile_path = "user://%s.log" % ProjectSettings.get_setting("application/config/name")
	_external_sinks = {}
	_loggers = {}
	_create_built_in_loggers()


func _exit_tree() -> void:
	_flush_external_sinks()


func add_external_sink(external_sink_config: Dictionary) -> ExternalSink:
	var factory := ExternalSinkFactory.new(
			funcref(_built_in, "warn"), funcref(self, "get_filepath_datetime"),
			default_logfile_path, default_filepath_time_format)
	var result: ExternalSink = factory.build(external_sink_config)
	if result.get_name() in _external_sinks:
		# xxx: LogFile doesn't interact with it's resource until write() is called, so it's fine to discard
		# after it's created. Other sinks might behave differently and it might be undesired to even create it
		# if the name already exists. In that case, ExternalSinkFactory should validate config before
		# creating the sink.
		_built_in.info("ExternalSink '%s' already exists; discarding the call to add it anew." % result.get_name())
		return _external_sinks[result.get_name()]
	_external_sinks[result.get_name()] = result
	return result


func get_external_sink_or_null(p_name: String) -> ExternalSink:
	if not p_name in _external_sinks:
		_built_in.warn("The requested ExternalSink '%s' doesn't exist." % p_name)
		return null
	return _external_sinks[p_name]


func add_logger(p_name: String, output_level: int = default_output_level,
		output_strategies: Array = default_output_strategies,
		output_format: String = default_output_format, time_format: String = default_time_format,
		external_sink: ExternalSink = _default.get_external_sink_or_null()) -> Logger:
	if p_name in _loggers:
		_built_in.info("Logger '%s' already exists; discarding the call to add it anew." % p_name)
	else:
		_loggers[p_name] = Logger.new(p_name, output_level, output_strategies,
				output_format, time_format, external_sink)
	return _loggers[p_name]


func get_logger(p_name: String = "") -> Logger:
	if p_name.empty():
		return _default
	if not p_name in _loggers:
		_built_in.info("The requested logger '%s' does not exist. It will be created with default values." % p_name)
		return add_logger(p_name)
	return _loggers[p_name]


func load_config(config_filepath: String) -> int:
	"""Load the configuration as well as the set of defined modules and
	their respective configurations. The expect file contents must be those
	produced by the ConfigFile API.
	Returns an error code (OK or some ERR_*)."""
	# Look for the file
	var directory = Directory.new()
	if not directory.file_exists(config_filepath):
		_built_in.warn("Could not load the config in '%s', the file does not exist." % config_filepath)
		return ERR_FILE_NOT_FOUND

	# Load its contents
	var config = ConfigFile.new()
	var error = config.load(config_filepath)
	if error:
		_built_in.warn("Could not load the config in '%s'; exited with error %d." % [config_filepath, error])
		return error
	
	return load_from_config(config, config_filepath)


func load_from_config(config: ConfigFile, config_filepath: String) -> int:
	self.default_output_level = config.get_value("logger",
			Constants.CONFIG_FIELDS.default_output_level, default_output_level)
	self.default_output_strategies = config.get_value("logger",
			Constants.CONFIG_FIELDS.default_output_strategies, default_output_strategies)
	self.default_output_format = config.get_value("logger",
			Constants.CONFIG_FIELDS.default_output_format, default_output_format)
	self.default_time_format = config.get_value("logger",
			Constants.CONFIG_FIELDS.default_time_format, default_time_format)
	self.default_filepath_time_format = config.get_value("logger",
			Constants.CONFIG_FIELDS.default_filepath_time_format, default_filepath_time_format)
	var original_default_logfile_path := default_logfile_path
	var new_default_logfile_path: String = config.get_value("logger",
			Constants.CONFIG_FIELDS.default_logfile_path, default_logfile_path)
	if new_default_logfile_path != original_default_logfile_path:
		self.default_logfile_path = new_default_logfile_path
	
	var datetime: Dictionary = OS.get_datetime()
	
	var factory := ExternalSinkFactory.new(
			funcref(_built_in, "warn"), funcref(self, "get_filepath_datetime"),
			default_logfile_path, default_filepath_time_format)
	for external_sink_config_ in config.get_value("logger", Constants.CONFIG_FIELDS.external_sinks, []):
		var external_sink_config := external_sink_config_ as Dictionary
		var external_sink: ExternalSink = factory.build(external_sink_config, datetime)
		if external_sink.get_name() in _external_sinks:
			_built_in.warn("ExternalSink '%s' already exists; overriding from config." % external_sink.get_name())
		_external_sinks[external_sink.get_name()] = external_sink
	
	for logger_config_ in config.get_value("logger", Constants.CONFIG_FIELDS.loggers, []):
		"""Example config:
		{
			"name": "MyLogger",
			"output_level": 2,
			"output_strategies": [3, 3, 3, 3, 3],
			"output_format": "[{TIME}] [{LVL}] [{MOD}]{ERR_MSG} {MSG}",
			"time_format": "hh:mm:ss",
			"external_sink": "user://path/to/log_{TIME}.log",
			"external_sink_time_format": "DD_hh-mm-ss",
		}
		"""
		var logger_config := logger_config_ as Dictionary
		var external_sink_time_format: String = logger_config.get(
				"external_sink_time_format", default_filepath_time_format)
		var external_sink_name: String = logger_config.get("external_sink", "")
		external_sink_name = external_sink_name.replace(Constants.FORMAT_IDS.time,
				get_filepath_datetime(datetime, external_sink_time_format))
		var logger := Logger.new(
				logger_config.get("name", ""),
				logger_config.get("output_level", default_output_level),
				logger_config.get("output_strategies", default_output_strategies),
				logger_config.get("output_format", default_output_format),
				logger_config.get("time_format", default_time_format),
				get_external_sink_or_null(external_sink_name))
		if logger.get_name() in _loggers:
			_built_in.warn("Logger '%s' already exists; overriding from config." % logger.get_name())
		_loggers[logger.get_name()] = logger
	
	_built_in.info("Successfully loaded the config from '%s'." % config_filepath)
	return OK


func get_filepath_datetime(datetime: Dictionary, time_format: String) -> String:
	var original_time_format := _built_in.time_format
	_built_in.time_format = time_format
	var result: String = _built_in.get_formatted_datetime(datetime)
	_built_in.time_format = original_time_format
	return result


func _create_built_in_loggers() -> void:
	_built_in = Logger.new("logger", default_output_level, default_output_strategies,
			default_output_format, default_time_format, null)
	_external_sinks[default_logfile_path] = LogFile.new(default_logfile_path)
	_default = Logger.new("main", default_output_level, default_output_strategies,
			default_output_format, default_time_format, _external_sinks[default_logfile_path])


func _flush_external_sinks() -> void:
	"""Flush non-empty buffers."""
	var processed_external_sinks := []
	var external_sink: ExternalSink = _default.get_external_sink_or_null()
	if external_sink:
		external_sink.flush_buffer()
		processed_external_sinks.push_back(external_sink)
	for logger_ in _loggers.values():
		var logger := logger_ as Logger
		external_sink = logger.get_external_sink_or_null()
		if not external_sink or external_sink in processed_external_sinks:
			continue
		external_sink.flush_buffer()
		processed_external_sinks.push_back(external_sink)


func set_default_output_level(new_value: int) -> void:
	var new_level: int = clamp(new_value, Constants.Level.VERBOSE, Constants.Level.ERROR)
	if new_level != new_value:
		_built_in.warn("Trying to assign out of bounds '%s' level; '%s' will be used." % [new_value, new_level])
	default_output_level = new_level
	_default.set_output_level(default_output_level)


func set_default_output_strategies(new_value) -> void:
	default_output_strategies = _built_in.sanitize_output_strategies_parameter(new_value)
	_default.set_output_strategies(default_output_strategies)


func set_default_output_format(new_value: String) -> void:
	default_output_format = new_value
	_default.set_output_format(default_output_format)


func set_default_time_format(new_value: String) -> void:
	default_time_format = new_value
	_default.time_format = default_time_format


func set_default_logfile_path(new_value: String, keep_old: bool = false) -> void:
	if new_value == default_logfile_path:
		return
	default_logfile_path = new_value
	if not keep_old:
		var external_sink: ExternalSink = add_external_sink({
			"type": "LogFile",
		})
		_default.set_external_sink(external_sink)
