from __future__ import annotations

import json
import sys
import types
from pathlib import Path
from typing import List
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def _install_stubs() -> None:
    if "gdtoolkit" not in sys.modules:
        gdtoolkit_module = types.ModuleType("gdtoolkit")
        parser_module = types.ModuleType("gdtoolkit.parser")
        parser_module.parser = types.SimpleNamespace(parse=lambda source: None)
        gdtoolkit_module.parser = parser_module
        sys.modules["gdtoolkit"] = gdtoolkit_module
        sys.modules["gdtoolkit.parser"] = parser_module

    if "lark" not in sys.modules:
        lark_module = types.ModuleType("lark")
        lark_module.exceptions = types.SimpleNamespace(LarkError=Exception)
        sys.modules["lark"] = lark_module


_install_stubs()

import pytest

import gdscript_parse_helper
from tools import codex_preflight


@pytest.fixture(autouse=True)
def _reset_sys_path():
    yield
    sys.path = list(dict.fromkeys(sys.path))


def _make_issue(tmp_path: Path) -> gdscript_parse_helper.ParseIssue:
    file_path = tmp_path / "demo.gd"
    file_path.write_text("extends Node\n")
    return gdscript_parse_helper.ParseIssue(
        path=file_path,
        message="unexpected indent",
        line=2,
        column=4,
        context=["mock"],
    )


def test_cli_reports_parse_failures_in_json(tmp_path, monkeypatch, capsys):
    issue = _make_issue(tmp_path)

    monkeypatch.setattr(
        codex_preflight,
        "collect_issues",
        mock.Mock(return_value=[issue]),
    )
    monkeypatch.setattr(
        codex_preflight,
        "iter_gd_files",
        mock.Mock(return_value=[issue.path]),
    )
    monkeypatch.setattr(
        codex_preflight,
        "read_context",
        mock.Mock(return_value=["   1: extends Node"]),
    )

    exit_code = codex_preflight.main([
        "--context-radius",
        "5",
        str(tmp_path),
    ])

    captured = capsys.readouterr()
    data = json.loads(captured.out)

    assert exit_code == 1
    assert data["telemetry"]["scripts_scanned"] == 1
    assert data["telemetry"]["parse_failures"] == 1
    assert data["parse"]["issues"][0]["context"] == ["   1: extends Node"]
    assert data["manifest"] == {"skipped": True}


def test_cli_runs_manifest_when_parse_succeeds(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(
        codex_preflight,
        "collect_issues",
        mock.Mock(return_value=[]),
    )
    monkeypatch.setattr(
        codex_preflight,
        "iter_gd_files",
        mock.Mock(return_value=[tmp_path / "a.gd", tmp_path / "b.gd"]),
    )

    manifest_payload = {
        "exit_code": 0,
        "summary": {
            "scripts_passed": 2,
            "scripts_failed": 0,
            "assertions": 5,
        },
        "scripts": [
            {"path": "res://tests/a.gd", "status": "PASS"},
            {"path": "res://tests/b.gd", "status": "PASS"},
        ],
    }

    manifest_calls: List[List[str]] = []

    def _fake_manifest(argv):
        manifest_calls.append(list(argv))
        print(json.dumps(manifest_payload, indent=2), file=sys.stderr)
        return 0

    monkeypatch.setattr(codex_preflight.manifest_runner, "main", _fake_manifest)

    exit_code = codex_preflight.main([
        str(tmp_path),
        "--manifest-args",
        "--project-root",
        "/project",
    ])

    captured = capsys.readouterr()
    output = json.loads(captured.out)

    assert exit_code == 0
    assert manifest_calls == [["--project-root", "/project"]]
    assert output["manifest"]["exit_code"] == 0
    assert output["manifest"]["summary"]["scripts_passed"] == 2
    assert output["telemetry"]["manifest_scripts_total"] == 2
    assert output["telemetry"]["manifest_attempted"] is True


def test_skip_parse_stage_allows_manifest_only(monkeypatch, capsys):
    manifest_payload = {
        "exit_code": 3,
        "summary": {
            "scripts_passed": 1,
            "scripts_failed": 1,
            "assertions": 4,
        },
    }

    def _fake_manifest(argv):
        print(json.dumps(manifest_payload, indent=2), file=sys.stderr)
        return manifest_payload["exit_code"]

    monkeypatch.setattr(codex_preflight.manifest_runner, "main", _fake_manifest)

    exit_code = codex_preflight.main([
        "--skip-parse",
        "--manifest-args",
        "--manifest",
        "tests/custom_manifest.json",
    ])

    captured = capsys.readouterr()
    data = json.loads(captured.out)

    assert exit_code == 3
    assert data["parse"] == {"skipped": True}
    assert data["telemetry"]["manifest_exit_code"] == 3
    assert data["telemetry"]["manifest_scripts_failed"] == 1
    assert data["manifest"]["exit_code"] == 3
