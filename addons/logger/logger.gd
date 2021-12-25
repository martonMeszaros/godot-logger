extends Reference
"""Class for customizable logging."""

const Constants := preload("constants.gd")
const ExternalSink := preload("external_sink.gd")


var time_format: String
var _name: String
var _output_level: int
var _output_strategies: Array
var _output_format: String
var _external_sink: ExternalSink


func _init(name: String, output_level: int, output_strategies: Array,
		output_format: String, p_time_format: String, external_sink: ExternalSink) -> void:
	_name = name
	_output_level = output_level
	_output_strategies = output_strategies
	_output_format = output_format
	time_format = p_time_format
	_external_sink = external_sink


func get_external_sink() -> ExternalSink:
	return _external_sink


# Format the fields:
# * YYYY = Year
# * MM = Month
# * DD = Day
# * hh = Hour
# * mm = Minutes
# * ss = Seconds
func get_formatted_datetime() -> String:
	var datetime: Dictionary = OS.get_datetime()
	var result := time_format
	result = result.replace("YYYY", "%04d" % [datetime.year])
	result = result.replace("MM", "%02d" % [datetime.month])
	result = result.replace("DD", "%02d" % [datetime.day])
	result = result.replace("hh", "%02d" % [datetime.hour])
	result = result.replace("mm", "%02d" % [datetime.minute])
	result = result.replace("ss", "%02d" % [datetime.second])
	return result


func verbose(message, error_code: int = -1):
	"""Log a message in the given module with level VERBOSE."""
	_put(Constants.Level.VERBOSE, message, error_code)


func debug(message, error_code: int = -1):
	"""Log a message in the given module with level DEBUG."""
	_put(Constants.Level.DEBUG, message, error_code)


func info(message, error_code: int = -1):
	"""Log a message in the given module with level INFO."""
	_put(Constants.Level.INFO, message, error_code)


func warn(message, error_code: int = -1):
	"""Log a message in the given module with level WARN."""
	_put(Constants.Level.WARN, message, error_code)


func error(message, error_code: int = -1):
	"""Log a message in the given module with level ERROR."""
	_put(Constants.Level.ERROR, message, error_code)


func _put(level: int, message, error_code: int) -> void:
	"""Log a message with the given logging level."""
	if _output_level > level or _output_strategies[level] == Constants.Strategy.MUTE:
		return # Out of scope
	
	var strategy := _output_strategies[level] as int
	var output: String = _format(level, message, error_code)
	if strategy & Constants.Strategy.PRINT:
		print(output)
	if strategy & Constants.Strategy.EXTERNAL_SINK:
		_external_sink.write(output, level)


func _format(level: int, message, error_code: int) -> String:
	var output := _output_format
	output = output.replace(Constants.FORMAT_IDS.level, Constants.LEVELS[level])
	output = output.replace(Constants.FORMAT_IDS.module, _name)
	output = output.replace(Constants.FORMAT_IDS.message, str(message))
	output = output.replace(Constants.FORMAT_IDS.time, get_formatted_datetime())
	
	# Error message substitution
	var error_message = Constants.ERROR_MESSAGES.get(error_code)
	if error_message != null:
		output = output.replace(Constants.FORMAT_IDS.error_message, " " + error_message)
	else:
		output = output.replace(Constants.FORMAT_IDS.error_message, "")
	
	return output


func set_output_level(new_value: int) -> void:
	var new_level: int = clamp(new_value, Constants.Level.VERBOSE, Constants.Level.ERROR)
	if new_level != new_value:
		warn("Trying to assign out of bounds '%s' level; '%s' will be used." % [new_value, new_level])
	_output_level = new_value


func set_output_strategies(new_value) -> void:
	_output_strategies = LogManager.sanitize_output_strategies_parameter(new_value, self)


func set_output_format(new_value: String) -> void:
	_output_format = new_value


func set_external_sink(new_value: ExternalSink) -> void:
	_external_sink = new_value
