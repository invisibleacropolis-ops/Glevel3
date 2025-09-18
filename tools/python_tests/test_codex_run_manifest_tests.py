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


def test_load_json_results_handles_corrupted_json(tmp_path):
    results_path = tmp_path / "results.json"
    results_path.write_text("{not-valid", encoding="utf-8")

    summary, scripts = codex_run_manifest_tests._load_json_results(results_path)

    assert summary.scripts_passed == 0
    assert summary.scripts_failed == 0
    assert summary.assertions == 0
    assert summary.error is not None
    assert "Failed to parse JSON results" in summary.error
    assert scripts == []


def test_execute_attempt_surfaces_corrupted_json(monkeypatch, tmp_path):
    json_path = tmp_path / "results.json"
    json_path.write_text("{broken", encoding="utf-8")

    xml_path = tmp_path / "results.xml"
    manifest_path = tmp_path / "tests_manifest.json"
    manifest_path.write_text("{}", encoding="utf-8")

    def fake_run_godot(*, project_root, godot_binary, extra_env=None):
        return 1, [], 0.1

    monkeypatch.setattr(codex_run_manifest_tests, "_run_godot", fake_run_godot)

    run = codex_run_manifest_tests._execute_attempt(
        attempt=1,
        max_attempts=1,
        project_root=tmp_path,
        godot_binary=tmp_path / "godot",
        manifest_path=manifest_path,
        json_path=json_path,
        xml_path=xml_path,
        cleanup=False,
    )

    assert run.summary.error is not None
    assert "Failed to parse JSON results" in run.summary.error
    assert run.scripts == []
    assert run.exit_code == 1
