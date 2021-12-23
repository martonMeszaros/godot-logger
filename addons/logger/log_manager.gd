extends Node

const Constants := preload("constants.gd")
const ExternalSink := preload("external_sink.gd")
const Logger := preload("logger.gd")


var default_output_level: int setget set_default_output_level
var default_output_strategies: Array setget set_default_output_strategies
var default_output_format: String setget set_default_output_format
var default_time_format: String setget set_default_time_format
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
	default_logfile_path = "user://%s.log" % ProjectSettings.get_setting("application/config/name")
	_create_built_in_logger()
	add_external_sink({
		"type": "logfile",
		"path": default_logfile_path,
		"queue_mode": 0,
	})
	_create_default_logger()


func _exit_tree() -> void:
	_flush_external_sinks()


func add_external_sink(external_sink_config: Dictionary) -> void:
	pass


func get_external_sink(p_name: String) -> void:
	pass


func add_logger(p_name: String, output_level: int = default_output_level,
		output_strategies: Array = default_output_strategies, output_format: String = default_output_format,
		time_format: String = default_time_format, external_sink: ExternalSink = null) -> Logger:
	if p_name in _loggers:
		_built_in.info("The logger '%s' already exists; discarding the call to add it anew." % p_name)
	else:
		pass
	return _loggers[p_name]


func get_logger(p_name: String = "") -> Logger:
	if p_name.empty():
		return _default
	if not p_name in _loggers:
		_built_in.info("The requested logger '%s' does not exist. It will be created with default values." % p_name)
		return add_logger(p_name)
	return _loggers[p_name]


func _create_built_in_logger() -> void:
	pass


func _create_default_logger() -> void:
	pass


func _flush_external_sinks() -> void:
	pass


func set_default_output_level(new_value: int) -> void:
	if new_value == default_output_level:
		return
	default_output_level = new_value
	_create_default_logger()


func set_default_output_strategies(new_value) -> void:
	if new_value == default_output_strategies:
		return
	if typeof(new_value) == TYPE_ARRAY:
		var array_size: int = len(new_value)
		for i in range(min(array_size, Constants.LEVELS.size())):
			default_output_strategies[i] = int(new_value[i])
		if array_size < Constants.LEVELS.size():
			_built_in.warn("Not enough strategies provided for each level %s; " +
					"%s will be used for the undefined level(s)." % [new_value, new_value[0]])
			for i in range(array_size, Constants.LEVELS.size()):
				default_output_strategies[i] = int(new_value[0])
	else:
		default_output_strategies = [
			int(new_value),
			int(new_value),
			int(new_value),
			int(new_value),
			int(new_value),
		]
	_create_default_logger()


func set_default_output_format(new_value: String) -> void:
	if new_value == default_output_format:
		return
	default_output_format = new_value
	_create_default_logger()


func set_default_time_format(new_value: String) -> void:
	if new_value == default_time_format:
		return
	default_time_format = new_value
	_create_default_logger()


func set_default_logfile_path(new_value: String, keep_old: bool = false) -> void:
	if new_value == default_logfile_path:
		return
	default_logfile_path = new_value
	if not keep_old:
		_create_default_logger()
