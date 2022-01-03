extends "external_sink.gd"
"""Class for log files that can be shared between various modules."""

const Level := preload("constants.gd").Level


const _FILE_BUFFER_SIZE := 30
const _ERROR_MESSAGE_TEMPLATE := "[ERROR] [logger] Could not open the '%s' log file; exited with error %d."

var _path: String
var _file: File
var _mutex: Mutex


func _init(path: String, queue_mode: int = QUEUE_MODE.NONE).(path, queue_mode) -> void:
	_path = path
	_file = File.new()
	_mutex = Mutex.new()
	_buffer.resize(_FILE_BUFFER_SIZE)
	assert(_path.is_abs_path() or _path.is_rel_path(), "Incorrect filepath '%s'." % _path)


func flush_buffer() -> void:
	"""Flush the buffer, i.e. write its contents to the target file."""
	# xxx: This method operates on _file, so lock guarding sould be required, but in theory,
	# it will only be called in safe circumstances:
	# a) wirte() locks the mutex,
	# b) LogManager._exit_tree() is only called once mostly everything else has been removed
	# from the scene tree, and any potetial threads should have been joined.
	# Take care in case another threaded global node gets deleted after this if it uses the logger.
	if _buffer_index == 0:
		return  # Nothing to write
	var error: int = _open_file()
	if error:
		return
	_file.seek_end()
	for i in range(_buffer_index):
		_file.store_line(_buffer[i])
	_file.close()
	_buffer_index = 0  # We don't clear the memory, we'll just overwrite it


func write(output: String, level: int) -> void:
	"""Write the string at the end of the file (append mode), following
	the queue mode."""
	_mutex.lock()
	var queue_action = _queue_mode
	if queue_action == QUEUE_MODE.SMART:
		if level >= Level.WARN:  # Don't queue warnings and errors
			queue_action = QUEUE_MODE.NONE
			flush_buffer()
		else:  # Queue the log, not important enough for "smart"
			queue_action = QUEUE_MODE.ALL
	
	if queue_action == QUEUE_MODE.NONE:
		var error: int = _open_file()
		if error:
			_mutex.unlock()
			return
		_file.seek_end()
		_file.store_line(output)
		_file.close()
	
	if queue_action == QUEUE_MODE.ALL:
		_buffer[_buffer_index] = output
		_buffer_index += 1
		if _buffer_index >= _FILE_BUFFER_SIZE:
			flush_buffer()
	_mutex.unlock()


func _open_file() -> int:
	var error: int = OK
	var write_mode: int = File.READ_WRITE if _file.file_exists(_path) else File.WRITE
	if write_mode == File.WRITE:
		if not (_path.is_abs_path() or _path.is_rel_path()):
			error = ERR_INVALID_PARAMETER
		if not error:
			var directory := Directory.new()
			var base_directory: String = _path.get_base_dir()
			if not directory.dir_exists(base_directory):
				error = directory.make_dir_recursive(base_directory)
	if error:
		print(_ERROR_MESSAGE_TEMPLATE % [_path, error])
		return error
	error = _file.open(_path, write_mode)
	if error:
		print(_ERROR_MESSAGE_TEMPLATE % [_path, error])
	return error
