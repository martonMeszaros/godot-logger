extends Reference


enum Level {
	VERBOSE = 0,
	DEBUG = 1,
	INFO = 2,
	WARNING = 3,
	ERROR = 4,
}

enum Strategy {
	MUTE = 0,
	PRINT = 1,
	EXTERNAL_SINK = 2,
	PRINT_AND_EXTERNAL_SINK = 3,
	MEMORY = 4,
}

const LEVELS := [
	"VERBOSE",
	"DEBUG",
	"INFO",
	"WARNING",
	"ERROR",
]
