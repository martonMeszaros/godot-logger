extends Reference

const Constants := preload("constants.gd")
const ExternalSink := preload("external_sink.gd")
const LogFile := preload("logfile.gd")


var _default_filepath_time_format: String
var _default_logfile_path: String


func _init(default_filepath_tiem_format: String, default_logifle_path: String) -> void:
	_default_filepath_time_format = default_filepath_tiem_format
	_default_logfile_path = default_logifle_path


func build(external_sink_config: Dictionary) -> ExternalSink:
	match external_sink_config.get("type"):
		"LogFile":
			return _build_logfile(external_sink_config)
	LogManager.warn("Incorrect ExternalSink config; creating empty ExternalSink.")
	return ExternalSink.new("", ExternalSink.QUEUE_MODE.NONE)


func _build_logfile(logfile_config: Dictionary) -> LogFile:
	"""Example config:
	{
		"type": "LogFile",
		"path": "user://path/to/log_{TIME}.log",
		"filepath_time_format": "DD_hh-mm-ss",
		"queue_mode": 2,
	}
	"""
	var time_format: String = logfile_config.get("filepath_time_format", _default_filepath_time_format)
	var datetime: String = LogManager.get_filepath_datetime(time_format)
	var path: String = logfile_config.get("path", _default_logfile_path)
	return LogFile.new(
			path.replace(Constants.FORMAT_IDS.time, datetime),
			logfile_config.get("queue_mode", ExternalSink.QUEUE_MODE.NONE))
