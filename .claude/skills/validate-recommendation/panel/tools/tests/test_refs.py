import pytest
from panel.tools import refs


class _Resp:
    def __init__(self, status):
        self.status_code = status
        self.headers = {}


def test_http_exists(monkeypatch):
    monkeypatch.setattr(refs, "_host_is_blocked", lambda host: False)
    monkeypatch.setattr(refs, "_http_head", lambda url: _Resp(200))
    assert refs.check_reference_exists("https://example.com/x") == "EXISTS"


def test_http_not_found(monkeypatch):
    monkeypatch.setattr(refs, "_host_is_blocked", lambda host: False)
    monkeypatch.setattr(refs, "_http_head", lambda url: _Resp(404))
    assert refs.check_reference_exists("https://example.com/missing").startswith("NOT_FOUND")


def test_ssrf_loopback_blocked():
    # literal IP => no DNS; the guard itself must flag loopback
    assert refs.check_reference_exists("http://127.0.0.1/admin").startswith("ERROR")


def test_ssrf_link_local_blocked():
    assert refs.check_reference_exists("http://169.254.169.254/latest/meta-data").startswith("ERROR")


def test_scheme_blocked():
    assert refs.check_reference_exists("file:///etc/passwd").startswith("ERROR")


def test_oci_manifest_exists(monkeypatch):
    monkeypatch.setattr(refs, "_host_is_blocked", lambda host: False)
    seen = {}
    def fake_head(url, headers=None):
        seen["url"] = url
        return _Resp(200)
    monkeypatch.setattr(refs, "_oci_head", fake_head)
    out = refs.check_reference_exists("oci://registry.example.com/library/ubuntu:24.04")
    assert out == "EXISTS"
    assert "/v2/library/ubuntu/manifests/24.04" in seen["url"]
