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
    # Assert the EXACT guard message — a bare startswith("ERROR") is theater: with the
    # guard deleted the call still returns ERROR (connection-refused), so it can't tell
    # "blocked by guard" from "network failed". Exact match fails iff the guard is gone.
    assert refs.check_reference_exists("http://127.0.0.1/admin") == "ERROR: blocked host (loopback/private/link-local)"


def test_ssrf_link_local_blocked():
    assert refs.check_reference_exists("http://169.254.169.254/latest/meta-data") == "ERROR: blocked host (loopback/private/link-local)"


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


def test_oci_blocked_registry_host():
    # literal loopback registry => real guard blocks before any network (exact message,
    # so removing the registry-host check fails this rather than hitting the network).
    assert refs.check_reference_exists("oci://127.0.0.1/lib/x:latest") == "ERROR: blocked registry host"


def test_oci_realm_ssrf_refused(monkeypatch):
    # Registry host allowed, but the 401 realm points at link-local: the realm SSRF
    # re-check must refuse the anon-token fetch WITHOUT any network call. _tracked_get
    # turns a missing re-check into a hard failure.
    monkeypatch.setattr(refs, "_host_is_blocked", lambda host: host.startswith("169.254"))

    class _R401:
        status_code = 401
        headers = {"Www-Authenticate": 'Bearer realm="http://169.254.169.254/token",service="r"'}

    monkeypatch.setattr(refs, "_oci_head", lambda url, headers=None: _R401())
    import httpx

    def _tracked_get(*a, **k):
        raise AssertionError("SSRF: realm token fetch reached the network")

    monkeypatch.setattr(httpx, "get", _tracked_get)
    out = refs.check_reference_exists("oci://registry.example.com/lib/x:latest")
    assert out == "ERROR: registry requires non-anonymous auth"
