extends SceneTree
## Headless test runner for the stat_system addon.
## Run with: godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"

const TESTS_DIR := "res://addons/stat_system/tests/"

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== stat_system test runner ===")
	var dir := DirAccess.open(TESTS_DIR)
	if not dir:
		push_error("Could not open tests directory: " + TESTS_DIR)
		quit(1)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var test_files: Array[String] = []
	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			test_files.append(TESTS_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	test_files.sort()

	for path in test_files:
		_run_file(path)

	print("=== %d passed, %d failed ===" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)

func _run_file(path: String) -> void:
	print("--- " + path)
	var script: GDScript = load(path)
	if script == null:
		_failures += 1
		print("  FAIL: could not load script")
		return
	var instance = script.new()
	if instance == null:
		_failures += 1
		print("  FAIL: could not instantiate")
		return

	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		var ok := _run_test_method(instance, method_name)
		if ok:
			_passes += 1
			print("  PASS: " + method_name)
		else:
			_failures += 1
			print("  FAIL: " + method_name)

func _run_test_method(instance: Object, method_name: String) -> bool:
	# Tests use `assert()` which crashes on failure in debug builds. We catch
	# nothing — a failure aborts the runner. Tests should return true on
	# success and false on failure for soft-assertion paths, OR rely on
	# assert() to abort. We treat any return value other than `false` as pass.
	var result = instance.call(method_name)
	return result != false
