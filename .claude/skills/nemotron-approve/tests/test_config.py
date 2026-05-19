"""Env var loading and validation."""
import pytest
from nemotron_approve.config import load_config, Config


def test_load_config_minimal(monkeypatch):
    monkeypatch.setenv("NEMOTRON_APPROVE_API_KEY", "k")
    monkeypatch.setenv("NEMOTRON_APPROVE_ENDPOINT", "https://e.example/v1")
    monkeypatch.setenv("NEMOTRON_APPROVE_MODEL", "nemotron-3-super")
    cfg = load_config()
    assert cfg.api_key == "k"
    assert cfg.endpoint == "https://e.example/v1"
    assert cfg.model == "nemotron-3-super"
    # Defaults
    assert cfg.timeout_seconds == 10
    assert cfg.max_tokens == 512
    assert cfg.disabled is False
    assert cfg.cache_ttl == 3600
    assert cfg.trace_enabled is True


def test_load_config_overrides(monkeypatch):
    monkeypatch.setenv("NEMOTRON_APPROVE_API_KEY", "k")
    monkeypatch.setenv("NEMOTRON_APPROVE_ENDPOINT", "https://e.example/v1")
    monkeypatch.setenv("NEMOTRON_APPROVE_MODEL", "m")
    monkeypatch.setenv("NEMOTRON_APPROVE_TIMEOUT", "5")
    monkeypatch.setenv("NEMOTRON_APPROVE_DISABLED", "1")
    monkeypatch.setenv("NEMOTRON_APPROVE_TRACE", "0")
    cfg = load_config()
    assert cfg.timeout_seconds == 5
    assert cfg.disabled is True
    assert cfg.trace_enabled is False


def test_load_config_missing_required_returns_disabled_config(monkeypatch):
    """If required vars are missing, return a config with .is_complete=False
    so the classifier can degrade to Lane A/B only."""
    monkeypatch.delenv("NEMOTRON_APPROVE_API_KEY", raising=False)
    monkeypatch.delenv("NEMOTRON_APPROVE_ENDPOINT", raising=False)
    monkeypatch.delenv("NEMOTRON_APPROVE_MODEL", raising=False)
    cfg = load_config()
    assert cfg.is_complete is False


def test_config_is_complete_when_all_required_set(monkeypatch):
    monkeypatch.setenv("NEMOTRON_APPROVE_API_KEY", "k")
    monkeypatch.setenv("NEMOTRON_APPROVE_ENDPOINT", "https://e.example/v1")
    monkeypatch.setenv("NEMOTRON_APPROVE_MODEL", "m")
    cfg = load_config()
    assert cfg.is_complete is True
