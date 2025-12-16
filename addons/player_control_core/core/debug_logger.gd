class_name DebugLogger
extends RefCounted
## Lightweight debug logging utility for player control systems.
##
## Provides conditional logging that can be toggled at runtime.
## Create an instance in your component and use log() for debug output.
## Disabled by default in release builds.


## Whether logging is enabled for this logger instance.
var enabled: bool = true

## Prefix added to all log messages (e.g., "[GroundedState]").
var prefix: String = ""

## Whether to include frame numbers in log output.
var include_frame_number: bool = true


## Create a new logger with optional prefix.
func _init(log_prefix: String = "", auto_enable: bool = true) -> void:
	prefix = log_prefix
	# Default to enabled in debug builds, disabled in release
	enabled = auto_enable and OS.is_debug_build()


## Log a debug message if logging is enabled.
func debug(message: String) -> void:
	if not enabled:
		return
	
	var output: String
	if include_frame_number:
		output = "%s Frame %d: %s" % [prefix, Engine.get_process_frames(), message]
	else:
		output = "%s %s" % [prefix, message]
	
	print(output)


## Log a formatted debug message with variable arguments.
func debugf(format: String, args: Array) -> void:
	if not enabled:
		return
	debug(format % args)


## Enable logging.
func enable() -> void:
	enabled = true


## Disable logging.
func disable() -> void:
	enabled = false


## Static helper to check if debug mode is active.
static func is_debug_mode() -> bool:
	return OS.is_debug_build()
