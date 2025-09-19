from __future__ import annotations

import io
import json
import subprocess
import threading
import time
from pathlib import Path
from typing import Iterable
from unittest import mock

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import pytest

from tools.codex_godot_process_manager import CodexGodotProcessManager


class FakeProcess:
    def __init__(self, stdout_lines: Iterable[str], stderr_lines: Iterable[str] | None = None):
        self.stdin = io.StringIO()
        self.stdout = io.StringIO("\n".join(stdout_lines) + ("\n" if stdout_lines else ""))
        stderr_lines = list(stderr_lines or [])
        self.stderr = io.StringIO("\n".join(stderr_lines) + ("\n" if stderr_lines else ""))
        self.pid = 4242
        self._returncode = None

    def poll(self):
        return self._returncode

    def wait(self, timeout=None):  # pragma: no cover - unused in tests
        self._returncode = 0
        return 0

    def terminate(self):  # pragma: no cover - unused in tests
        self._returncode = 0

    def kill(self):  # pragma: no cover - unused in tests
        self._returncode = -9


class SlowExitProcess(FakeProcess):
    def __init__(self, stdout_lines: Iterable[str], exit_code: int = 0):
        super().__init__(stdout_lines)
        self._exit_code = exit_code
        self._wait_event = threading.Event()
        self.wait_calls = 0

    def wait(self, timeout=None):
        self.wait_calls += 1
        if timeout is None:
            raise AssertionError("wait() should receive a timeout when managed by CodexGodotProcessManager")
        if not self._wait_event.wait(timeout):
            raise subprocess.TimeoutExpired(cmd=["godot"], timeout=timeout)
        self._returncode = self._exit_code
        return self._exit_code

    def terminate(self):
        super().terminate()
        self._wait_event.set()

    def kill(self):
        super().kill()
        self._wait_event.set()

    def trigger_exit(self):
        self._wait_event.set()


@pytest.fixture(autouse=True)
def _set_env(monkeypatch):
    monkeypatch.setenv("CODEX_GODOT_BIN", "godot")
    monkeypatch.setenv("CODEX_PROJECT_ROOT", "/project")


def test_start_sends_banner_request(monkeypatch):
    process = FakeProcess(["{\"id\":0,\"result\":{\"banner\":\"ok\"}}"])
    monkeypatch.setattr("subprocess.Popen", mock.Mock(return_value=process))

    manager = CodexGodotProcessManager()
    manager.start()

    lines = [json.loads(line) for line in process.stdin.getvalue().splitlines()]
    assert lines[0]["method"] == "codex.banner"
    assert lines[0]["params"]["client"] == "codex"

    command_id = manager.send_command("scene.load", {"path": "res://test.tscn"})
    assert command_id == 1
    assert json.loads(process.stdin.getvalue().splitlines()[-1]) == {
        "id": 1,
        "method": "scene.load",
        "params": {"path": "res://test.tscn"},
    }

    manager.stop()


def test_wait_delegates_to_process_wait(monkeypatch):
    process = FakeProcess(["{\"id\":0,\"result\":{\"banner\":\"ok\"}}"])
    wait_mock = mock.Mock(return_value=7)
    process.wait = wait_mock
    monkeypatch.setattr("subprocess.Popen", mock.Mock(return_value=process))

    manager = CodexGodotProcessManager()
    manager.start()

    exit_code = manager.wait()
    assert exit_code == 7
    wait_mock.assert_called()

    manager.stop()


def test_wait_handles_timeout_and_shutdown(monkeypatch):
    process = SlowExitProcess(["{\"id\":0,\"result\":{\"banner\":true}}"], exit_code=11)
    monkeypatch.setattr("subprocess.Popen", mock.Mock(return_value=process))

    manager = CodexGodotProcessManager()
    manager.start()

    def _release_process():
        time.sleep(0.35)
        process.trigger_exit()

    threading.Thread(target=_release_process, daemon=True).start()

    exit_code = manager.wait(timeout=1.0)
    assert exit_code == 11
    assert process.wait_calls >= 2  # ensure TimeoutExpired was raised at least once

    manager.stop()


def test_wait_respects_timeout(monkeypatch):
    process = SlowExitProcess(["{\"id\":0,\"result\":{\"banner\":42}}"], exit_code=3)
    monkeypatch.setattr("subprocess.Popen", mock.Mock(return_value=process))

    manager = CodexGodotProcessManager()
    manager.start()

    with pytest.raises(TimeoutError):
        manager.wait(timeout=0.05)

    manager.stop()


def test_iter_messages_skips_banner(monkeypatch):
    process = FakeProcess(
        [
            "{\"id\":0,\"result\":{\"banner\":\"hello\"}}",
            "{\"id\":1,\"result\":{\"ok\":true}}",
        ]
    )
    monkeypatch.setattr("subprocess.Popen", mock.Mock(return_value=process))

    manager = CodexGodotProcessManager()
    manager.start()

    iterator = manager.iter_messages(timeout=0.1)
    message = next(iterator)
    assert message == {"id": 1, "result": {"ok": True}}

    description = manager.describe_session()
    assert description.banner == {"banner": "hello"}

    assert manager.wait_for_banner() == {"banner": "hello"}

    manager.stop()


def test_diagnostics_surface_for_non_json(monkeypatch):
    process = FakeProcess(
        [
            "{\"id\":0,\"result\":{\"banner\":\"banner\"}}",
            "not json",
            "{\"id\":1,\"result\":42}",
        ],
        stderr_lines=["engine: warning"],
    )
    monkeypatch.setattr("subprocess.Popen", mock.Mock(return_value=process))

    manager = CodexGodotProcessManager()
    manager.start()

    iterator = manager.iter_messages(timeout=0.1)
    assert next(iterator)["result"] == 42

    time.sleep(0.05)
    manager.stop()

    diagnostics = list(manager.iter_stderr_diagnostics())
    assert any(entry["stream"] == "stdout" and entry["level"] == "protocol" for entry in diagnostics)
    assert any(entry["stream"] == "stderr" and entry["text"].startswith("engine") for entry in diagnostics)

    manager.stop()


def test_heartbeat_timeout_emits_diagnostic(monkeypatch):
    process = FakeProcess(["{\"id\":0,\"result\":{\"banner\":\"b\"}}"])
    monkeypatch.setattr("subprocess.Popen", mock.Mock(return_value=process))

    manager = CodexGodotProcessManager(heartbeat_interval=0.05, heartbeat_timeout=0.01)
    manager.start()

    time.sleep(0.1)
    manager.stop()

    diagnostics = list(manager.iter_stderr_diagnostics())
    assert any(entry["stream"] == "heartbeat" for entry in diagnostics)

    manager.stop()


def test_wait_for_banner_buffers_messages(monkeypatch):
    process = FakeProcess(
        [
            "{\"id\":1,\"result\":{\"ok\":true}}",
            "{\"id\":0,\"result\":{\"banner\":\"later\"}}",
        ]
    )
    monkeypatch.setattr("subprocess.Popen", mock.Mock(return_value=process))

    manager = CodexGodotProcessManager()
    manager.start()

    iterator = manager.iter_messages(timeout=0.1)
    assert next(iterator) == {"id": 1, "result": {"ok": True}}

    manager.stop()


def test_start_times_out_without_banner(monkeypatch):
    class HangingStdout:
        def __init__(self):
            self._closed = False

        def readline(self, size=-1):  # pragma: no cover - size unused
            time.sleep(0.02)
            return "" if self._closed else "\n"

        def close(self):
            self._closed = True

    class HangingProcess(FakeProcess):
        def __init__(self):
            super().__init__([])
            self.stdout = HangingStdout()

    process = HangingProcess()
    monkeypatch.setattr("subprocess.Popen", mock.Mock(return_value=process))

    manager = CodexGodotProcessManager(banner_timeout=0.01)

    with pytest.raises(TimeoutError):
        manager.start()

    diagnostics = list(manager.iter_stderr_diagnostics())
    assert any(entry["stream"] == "banner" for entry in diagnostics)
