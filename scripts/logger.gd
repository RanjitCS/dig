extends Node

const LOG_PATH: String = "res://logs/debug.log"
const FALLBACK_PATH: String = "user://debug.log"

enum Level { DEBUG, INFO, WARN, ERROR }
const LEVEL_NAMES := ["DBG", "INF", "WRN", "ERR"]

var _file: FileAccess = null
var _started_at_unix: int = 0
var _active_path: String = ""

func _ready() -> void:
	_started_at_unix = int(Time.get_unix_time_from_system())
	_open_fresh()
	inf("=== log start (unix=%d) ===" % _started_at_unix)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if _file != null:
			_file.flush()
			_file.close()
			_file = null

func _open_fresh() -> void:
	# Ensure logs dir exists when writing to res:// in the editor.
	var dir := DirAccess.open("res://")
	if dir != null and not dir.dir_exists("logs"):
		dir.make_dir("logs")
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _file == null:
		_file = FileAccess.open(FALLBACK_PATH, FileAccess.WRITE)
		_active_path = FALLBACK_PATH
	else:
		_active_path = LOG_PATH

func _write(level: int, msg: String) -> void:
	var line := "[%.3f] %s %s" % [
		Time.get_ticks_msec() / 1000.0,
		LEVEL_NAMES[level],
		msg,
	]
	print(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()

func dbg(msg: String) -> void:
	_write(Level.DEBUG, msg)

func inf(msg: String) -> void:
	_write(Level.INFO, msg)

func wrn(msg: String) -> void:
	_write(Level.WARN, msg)

func err(msg: String) -> void:
	_write(Level.ERROR, msg)

func path() -> String:
	return _active_path
