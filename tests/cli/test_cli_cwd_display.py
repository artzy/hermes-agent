"""Classic CLI always surfaces the workspace cwd in prompt + status bar."""

from datetime import datetime

from cli import HermesCLI


def _make_cli():
    cli_obj = HermesCLI.__new__(HermesCLI)
    cli_obj.model = "anthropic/claude-opus-4.6"
    cli_obj.agent = None
    cli_obj._background_tasks = {}
    cli_obj.session_start = datetime.now()
    cli_obj._status_bar_visible = True
    cli_obj._voice_recording = False
    cli_obj._voice_processing = False
    cli_obj._voice_mode = False
    cli_obj._sudo_state = None
    cli_obj._secret_state = None
    cli_obj._approval_state = None
    cli_obj._slash_confirm_state = None
    cli_obj._clarify_freetext = False
    cli_obj._clarify_state = None
    cli_obj._command_running = False
    cli_obj._agent_running = False
    return cli_obj


def test_short_cwd_label_abbrev_home(tmp_path, monkeypatch):
    monkeypatch.setattr("os.path.expanduser", lambda p: str(tmp_path) if p == "~" else p)
    nested = tmp_path / "proj" / "src"
    nested.mkdir(parents=True)
    label = HermesCLI._short_cwd_label(str(nested), max_len=40)
    assert label.startswith("~")
    assert label.replace("\\", "/").endswith("proj/src")


def test_short_cwd_label_truncates_long_path():
    long_path = "/a/" + ("very-long-segment/" * 8) + "end"
    label = HermesCLI._short_cwd_label(long_path, max_len=20)
    assert len(label) <= 20
    assert label.startswith("…")
    assert label.endswith("end")


def test_snapshot_includes_terminal_cwd(monkeypatch, tmp_path):
    monkeypatch.setenv("TERMINAL_CWD", str(tmp_path))
    cli_obj = _make_cli()
    snap = cli_obj._get_status_bar_snapshot()
    assert snap["cwd"] == str(tmp_path)
    assert snap["cwd_short"]


def test_status_bar_text_includes_cwd(monkeypatch, tmp_path):
    monkeypatch.setenv("TERMINAL_CWD", str(tmp_path / "workspace"))
    (tmp_path / "workspace").mkdir()
    cli_obj = _make_cli()
    text = cli_obj._build_status_bar_text(width=120)
    assert "workspace" in text


def test_status_bar_fragments_include_cwd(monkeypatch, tmp_path):
    monkeypatch.setenv("TERMINAL_CWD", str(tmp_path / "repo"))
    (tmp_path / "repo").mkdir()
    cli_obj = _make_cli()
    cli_obj._get_tui_terminal_width = lambda: 120  # type: ignore[method-assign]
    rendered = "".join(text for _style, text in cli_obj._get_status_bar_fragments())
    assert "repo" in rendered


def test_idle_prompt_includes_cwd(monkeypatch, tmp_path):
    monkeypatch.setenv("TERMINAL_CWD", str(tmp_path / "workdir"))
    (tmp_path / "workdir").mkdir()
    cli_obj = _make_cli()
    cli_obj._get_tui_terminal_width = lambda: 100  # type: ignore[method-assign]
    rendered = "".join(text for _style, text in cli_obj._get_tui_prompt_fragments())
    assert "workdir" in rendered
    assert "❯" in rendered or ">" in rendered or rendered.strip()
