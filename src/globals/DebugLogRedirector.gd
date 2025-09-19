extends Node
class_name DebugLogRedirectorSingleton

## Engine singleton identifier used to locate the low-level logging interface.
const LOGGER_SINGLETON_NAME := "Logger"
## Maximum number of deferred attempts to hook the engine logger before giving up.
const LOGGER_RETRY_LIMIT := 5

## Autoload singleton that intercepts Godot's global logger and forwards messages
## to the active DebugSystem instance. Designed for Godot 4.4.1.
##
## The redirector keeps the engine's original logging behaviour intact by
## chaining calls to the previous logger callback after forwarding the message to
## DebugSystem. Gameplay scenes can opt into log capture by registering their
## DebugSystem node via `register_debug_system()` when it enters the scene tree.
## Once the system exits the tree it must call `unregister_debug_system()` so the
## redirector stops sending messages to a freed object.

static var _singleton: DebugLogRedirectorSingleton = null

var _active_debug_system: WeakRef = null
var _previous_log_func: Callable = Callable()
var _logger_callable: Callable = Callable()
var _is_logger_installed := false
## Count of installation retries attempted since the node entered the tree.
var _retry_attempts := 0
## Tracks whether a deferred retry has already been scheduled for the current frame.
var _is_retry_queued := false
## Prevents duplicate log spam when the logger interface is unavailable.
var _has_reported_install_issue := false

func _enter_tree() -> void:
    _singleton = self

func _ready() -> void:
    if not _install_logger():
        _queue_logger_retry()

func _exit_tree() -> void:
    if _singleton == self:
        _singleton = null
    _uninstall_logger()
    _active_debug_system = null

static func get_singleton() -> DebugLogRedirectorSingleton:
    return _singleton

static func is_singleton_ready() -> bool:
    return is_instance_valid(_singleton)

## Registers the provided DebugSystem (or compatible node) as the recipient of
## intercepted log messages. Only one system is tracked at a time; subsequent
## registrations replace the previous weak reference so new scenes can take
## ownership of the logger without leaking old references.
func register_debug_system(system: Node) -> void:
    if system == null:
        return
    _active_debug_system = weakref(system)

## Clears the active DebugSystem reference when the caller matches the tracked
## instance. This guard prevents unrelated nodes from accidentally disabling log
## forwarding while still handling the common case where the referenced node has
## already been freed.
func unregister_debug_system(system: Node) -> void:
    if _active_debug_system == null:
        return

    var current_object: Object = _active_debug_system.get_ref()
    if not is_instance_valid(current_object) or current_object == system:
        _active_debug_system = null

## Resolves the engine logger singleton when available.
## Returns null when running in environments (such as stripped-down test harnesses)
## that do not expose Godot's Logger interface.
func _get_logger_singleton() -> Object:
    if not Engine.has_singleton(LOGGER_SINGLETON_NAME):
        return null

    var logger_singleton: Object = Engine.get_singleton(LOGGER_SINGLETON_NAME)
    if logger_singleton == null:
        return null

    return logger_singleton

## Installs a custom logger callback that relays messages to DebugSystem while
## preserving the engine's native logging behaviour. The implementation probes
## for `Logger.set_log_func` and `Logger.get_log_func` at runtime so the redirect
## safely degrades when running in environments that do not expose the Logger
## interface (for example, stripped-down test runners).
func _install_logger() -> bool:
    if _is_logger_installed:
        return true

    var logger: Object = _get_logger_singleton()
    if logger == null:
        _report_logger_issue(
            "Logger singleton is unavailable; DebugLogRedirectorSingleton cannot intercept log output."
        )
        return false

    var set_callable: Callable = Callable(logger, "set_log_func")
    if not set_callable.is_valid():
        _report_logger_issue(
            "Logger.set_log_func is unavailable; DebugLogRedirectorSingleton cannot intercept log output."
        )
        return false

    var get_callable: Callable = Callable(logger, "get_log_func")
    if get_callable.is_valid():
        var previous_result: Variant = get_callable.call()
        if previous_result is Callable:
            _previous_log_func = previous_result

    _logger_callable = Callable(self, "_on_log_message")
    set_callable.call(_logger_callable)
    _is_logger_installed = true
    _retry_attempts = 0
    _is_retry_queued = false
    _has_reported_install_issue = false
    return true

## Restores the previous logger callback so the engine's logging stack returns to
## its default configuration. Called automatically when the singleton exits the
## tree (e.g., during project shutdown).
func _uninstall_logger() -> void:
    if not _is_logger_installed:
        return

    var logger: Object = _get_logger_singleton()
    if logger != null:
        var set_callable: Callable = Callable(logger, "set_log_func")
        if set_callable.is_valid():
            if _previous_log_func.is_valid():
                set_callable.call(_previous_log_func)
            else:
                set_callable.call(Callable())
    
    _is_logger_installed = false
    _logger_callable = Callable()
    _previous_log_func = Callable()
    _retry_attempts = 0
    _is_retry_queued = false
    _has_reported_install_issue = false

## Internal helper that resolves the currently registered DebugSystem instance.
## The weak reference automatically clears itself when the system is freed,
## ensuring `_on_log_message` never attempts to call methods on a deleted node.
func _resolve_active_debug_system() -> Node:
    if _active_debug_system == null:
        return null

    var instance_object: Object = _active_debug_system.get_ref()
    if not is_instance_valid(instance_object):
        _active_debug_system = null
        return null

    var instance_node: Node = instance_object as Node
    if instance_node == null:
        _active_debug_system = null
        return null

    return instance_node

## Custom logger callback wired into Godot's logging pipeline. The redirector
## forwards each message to the active DebugSystem (if available) and then invokes
## the original logger callback so standard console output remains intact.
func _on_log_message(message: String, level: int, category: String, timestamp: String) -> void:
    var debug_system: Node = _resolve_active_debug_system()
    if debug_system and debug_system.has_method("capture_log_message"):
        debug_system.capture_log_message(message, level, category, timestamp)

    if _previous_log_func.is_valid():
        _previous_log_func.call(message, level, category, timestamp)

## Schedules a deferred logger installation attempt so the singleton can hook the
## engine logger after other subsystems finish initialising. Retries are limited
## to avoid infinite loops in stripped-down builds that omit the Logger API.
func _queue_logger_retry() -> void:
    if not is_inside_tree():
        return
    if _is_logger_installed:
        return
    if _retry_attempts >= LOGGER_RETRY_LIMIT:
        _report_logger_issue(
            "Logger installation retries exhausted; DebugLogRedirectorSingleton will operate without interception."
        )
        return
    if _is_retry_queued:
        return
    _is_retry_queued = true
    call_deferred("_retry_install_logger")

## Executes the deferred installation attempt queued by `_queue_logger_retry` and
## schedules additional retries when the logger is still unavailable.
func _retry_install_logger() -> void:
    _is_retry_queued = false
    if _is_logger_installed:
        return
    if not is_inside_tree():
        return
    _retry_attempts += 1
    if not _install_logger():
        _queue_logger_retry()

## Emits a single diagnostic message describing why the logger hook failed.
## Editor sessions use `push_warning` for visibility while headless test runs fall
## back to `print_verbose` to keep their logs noise-free.
func _report_logger_issue(message: String) -> void:
    if _has_reported_install_issue:
        return
    _has_reported_install_issue = true
    if Engine.is_editor_hint():
        push_warning(message)
    else:
        print_verbose("DebugLogRedirectorSingleton: %s" % message)
