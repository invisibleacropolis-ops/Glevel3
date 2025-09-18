# Codex Automation Process Manager

The `tools/codex_godot_process_manager.py` module provides the Python-facing
wrapper that Codex uses to launch and supervise headless Godot sessions.  It
is designed to follow the communication and orchestration guidelines described
in the "Python Godot Automation Design Bible" so that outside engineers can
easily integrate Codex-driven automation into their own tooling.

## Environment variables

Two environment variables define the default launch configuration:

- `CODEX_GODOT_BIN`: Absolute path to the Godot 4 executable to run.  The
  module will refuse to start if this is not provided either via the
  environment or the class constructor.
- `CODEX_PROJECT_ROOT`: Path to the Godot project that should be mounted via
  `--path`.  This directory must contain the canonical `project.godot` file.

Both variables can be overridden by passing explicit values to the
`CodexGodotProcessManager` constructor.  Manual operators often provide custom
arguments or environment tweaks while Codex production runs typically rely on
CI provided defaults.

## Session lifecycle

```python
from tools.codex_godot_process_manager import CodexGodotProcessManager

with CodexGodotProcessManager(extra_args=["-s", "res://tests/run_all_tests.gd"]) as manager:
    # Send JSON-RPC commands and iterate over responses.
    request_id = manager.send_command("scenario.load", {"name": "Arena"})
    for message in manager.iter_messages(timeout=1.0):
        print(message)
```

- `start()` launches `godot --headless --path <project>` with the configured
  arguments and immediately sends an automatic `codex.banner` negotiation
  request.  The response is captured and surfaced via
  `manager.describe_session().banner`.
- `stop()` gracefully terminates the process and joins the reader threads.  A
  context manager (`with` block) is provided for convenience.

## Communication model

- Commands are serialized as JSON-RPC style dictionaries with a monotonically
  increasing `id`, a `method` string, and a `params` dictionary.  Each command
  is written as a single newline-delimited JSON document on stdin.
- Responses are consumed through `iter_messages()`, which parses each newline
  from stdout and yields decoded dictionaries.  The banner response is
  consumed internally so user code only sees domain-specific payloads.
- Any stdout line that fails JSON parsing or every stderr line is converted
  into a structured diagnostic record.  These records can be inspected via
  `iter_stderr_diagnostics()` and include timestamps, severity levels, and the
  originating stream.

## Heartbeat and timeout handling

Codex runs are often unattended, so the manager includes a lightweight
heartbeat monitor.  When `heartbeat_interval` is provided the manager wakes up
periodically to check when the last stdout message was seen.  If the elapsed
silence exceeds `heartbeat_timeout` (defaults to the interval) a warning
record with `stream="heartbeat"` is injected into the diagnostics queue.
This allows Codex to detect hung scenarios without preventing manual
operators from running longer experiments (set the interval to `None` to
disable the watchdog).

## Introspection

`describe_session()` returns a `SessionDescription` dataclass containing the
active command line, process ID, negotiated banner, and heartbeat settings.
This makes it straightforward to mirror Codex' perspective on a live session
when debugging in external tooling or when collecting telemetry for CI.
