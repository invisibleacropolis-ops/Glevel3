from pathlib import Path
from unittest import mock

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools import codex_run_manifest_tests


def test_run_godot_uses_public_wait(monkeypatch):
    wait_mock = mock.Mock(return_value=0)
    diagnostics = [
        {"timestamp": 123.4, "stream": "stderr", "text": "note", "level": "info"}
    ]
    created = []

    class FakeManager:
        def __init__(self, **kwargs):
            self.kwargs = kwargs
            created.append(self)

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def wait(self):
            return wait_mock()

        def iter_stderr_diagnostics(self):
            for payload in diagnostics:
                yield payload

    monkeypatch.setattr(
        codex_run_manifest_tests, "CodexGodotProcessManager", FakeManager
    )

    exit_code, logs, duration = codex_run_manifest_tests._run_godot(
        project_root=Path("/project"),
        godot_binary=Path("/godot"),
    )

    assert exit_code == 0
    assert wait_mock.called
    assert duration >= 0.0
    assert logs == [
        {"timestamp": "123.4", "stream": "stderr", "text": "note", "level": "info"}
    ]

    manager = created[0]
    assert manager.kwargs["godot_binary"] == "/godot"
    assert manager.kwargs["project_root"] == "/project"
