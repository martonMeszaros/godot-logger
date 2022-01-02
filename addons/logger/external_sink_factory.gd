extends Reference

const Constants := preload("constants.gd")
const ExternalSink := preload("external_sink.gd")
const LogFile := preload("logfile.gd")


var _warn: FuncRef
var _get_filepath_datetime: FuncRef
var _default_logfile_path: String
var _default_filepath_time_format: String


func _init(warn: FuncRef, get_filepath_datetime: FuncRef,
		default_logfile_path: String, default_filepath_tiem_format: String) -> void:
	_warn = warn
	_get_filepath_datetime = get_filepath_datetime
	_default_logfile_path = default_logfile_path
	_default_filepath_time_format = default_filepath_tiem_format


func build(external_sink_config: Dictionary, datetime: Dictionary = OS.get_datetime()) -> ExternalSink:
	match external_sink_config.get("type"):
		"LogFile":
			return _build_logfile(external_sink_config, datetime)
	_warn.call_func("Incorrect ExternalSink config; creating empty ExternalSink.")
	return ExternalSink.new("", ExternalSink.QUEUE_MODE.NONE)


func _build_logfile(logfile_config: Dictionary, datetime: Dictionary) -> LogFile:
	"""Example config:
	{
		"type": "LogFile",
		"path": "user://path/to/log_{TIME}.log",
		"filepath_time_format": "DD_hh-mm-ss",
		"queue_mode": 2,
	}
	"""
	var time_format: String = logfile_config.get("filepath_time_format", _default_filepath_time_format)
	var formatted_datetime: String = _get_filepath_datetime.call_func(datetime, time_format)
	var path: String = logfile_config.get("path", _default_logfile_path)
	return LogFile.new(
			path.replace(Constants.FORMAT_IDS.time, formatted_datetime),
			logfile_config.get("queue_mode", ExternalSink.QUEUE_MODE.NONE))
