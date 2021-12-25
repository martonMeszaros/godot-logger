extends Reference


enum QUEUE_MODE {
	NONE = 0,
	ALL = 1,
	SMART = 2,
}

var _name: String
var _queue_mode: int
var _buffer: PoolStringArray
var _buffer_index: int


func _init(name: String, queue_mode: int) -> void:
	_name = name
	_queue_mode = queue_mode
	_buffer = PoolStringArray()
	_buffer_index = 0


func get_name() -> String:
	return _name


func flush_buffer() -> void:
	"""Flush the buffer, i.e. write its contents to the target external sink."""
	pass


func write(_output: String, _level: int) -> void:
	"""Write the string at the end of the sink (append mode), following
	the queue mode."""
	pass
