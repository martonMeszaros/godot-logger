extends Node

const Constants := preload("constants.gd")
const ExternalSink := preload("external_sink.gd")
const ExternalSinkFactory := preload("external_sink_factory.gd")
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
	_create_built_in_logger()
	var default_external_sink: ExternalSink = add_external_sink({
		"type": "LogFile",
	})
	_create_default_logger(default_external_sink)


func _exit_tree() -> void:
	_flush_external_sinks()


func add_external_sink(external_sink_config: Dictionary) -> ExternalSink:
	var factory := ExternalSinkFactory.new(default_filepath_time_format, default_logfile_path)
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


func get_external_sink(p_name: String) -> ExternalSink:
	if not p_name in _external_sinks:
		_built_in.error("The requested ExternalSink '%s' doesn't exist." % p_name)
		return null
	return _external_sinks[p_name]


func add_logger(p_name: String, output_level: int = default_output_level,
		output_strategies: Array = default_output_strategies, output_format: String = default_output_format,
		time_format: String = default_time_format, external_sink: ExternalSink = _default.get_external_sink()) -> Logger:
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




func warn(message, error_code: int = -1) -> void:
	_built_in.warn(message, error_code)


func get_filepath_datetime(time_format: String) -> String:
	var original_time_format := _built_in.time_format
	_built_in.time_format = time_format
	var result: String = _built_in.get_formatted_datetime()
	_built_in.time_format = original_time_format
	return result


func sanitize_output_strategies_parameter(strategies, logger: Logger = _built_in) -> Array:
	var result := []
	if typeof(strategies) == TYPE_ARRAY:
		var array_size: int = len(strategies)
		for i in range(min(array_size, Constants.LEVELS.size())):
			var unsanitized := strategies[i] as int
			var sanitized: int = clamp(unsanitized, Constants.Strategy.MUTE, Constants.Strategy.PRINT_AND_EXTERNAL_SINK)
			if sanitized != unsanitized:
				logger.info("Trying to use out of bounds '%s' strategy; '%s' will be used instead." % [
						unsanitized, sanitized])
			result.push_back(sanitized)
		if array_size < Constants.LEVELS.size():
			logger.warn("Not enough strategies provided for each level %s; " +
					"'%s' will be used for the undefined level(s)." % [strategies, result[0]])
			for _i in range(array_size, Constants.LEVELS.size()):
				result.push_back(result[0])
	else:
		var unsanitized := strategies as int
		var sanitized: int = clamp(unsanitized, Constants.Strategy.MUTE, Constants.Strategy.PRINT_AND_EXTERNAL_SINK)
		if sanitized != unsanitized:
			logger.info("Trying to use out of bounds '%s' strategy; '%s' will be used instead." % [
					unsanitized, sanitized])
		result = [
			sanitized,
			sanitized,
			sanitized,
			sanitized,
			sanitized,
		]
	return result


func _create_built_in_logger() -> void:
	pass


func _create_default_logger() -> void:
	pass


func _flush_external_sinks() -> void:
	pass


func set_default_output_level(new_value: int) -> void:
	var new_level: int = clamp(new_value, Constants.Level.VERBOSE, Constants.Level.ERROR)
	if new_level != new_value:
		_built_in.warn("Trying to assign out of bounds '%s' level; '%s' will be used." % [new_value, new_level])
	default_output_level = new_level
	_default.set_output_level(default_output_level)


func set_default_output_strategies(new_value) -> void:
	default_output_strategies = sanitize_output_strategies_parameter(new_value)
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
