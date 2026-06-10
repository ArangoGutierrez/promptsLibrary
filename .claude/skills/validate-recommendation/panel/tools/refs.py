"""check_reference_exists: verify a URL or OCI image ref actually exists.

SSRF-guarded: scheme allow-list, deny loopback/link-local/private/.local hosts,
HEAD only, short timeout. httpx is wrapped in _http_head/_oci_head so tests mock
those two seams without touching the network.
"""
from __future__ import annotations
import ipaddress
import socket
from urllib.parse import urlparse

_TIMEOUT = 5.0
_ALLOWED_SCHEMES = {"http", "https", "oci"}


def _host_is_blocked(host: str) -> bool:
    if not host or host.endswith(".local") or host == "localhost":
        return True
    try:
        infos = socket.getaddrinfo(host, None)
    except OSError:
        return True  # unresolvable -> treat as blocked
    for *_unused, sockaddr in infos:
        ip = ipaddress.ip_address(sockaddr[0])
        if ip.is_loopback or ip.is_link_local or ip.is_private or ip.is_reserved or ip.is_multicast:
            return True
    return False


def _http_head(url: str):
    import httpx
    return httpx.head(url, follow_redirects=False, timeout=_TIMEOUT)


def _oci_head(url: str, headers=None):
    import httpx
    return httpx.head(url, headers=headers or {}, follow_redirects=False, timeout=_TIMEOUT)


def _check_http(url: str) -> str:
    parsed = urlparse(url)
    if _host_is_blocked(parsed.hostname or ""):
        return "ERROR: blocked host (loopback/private/link-local)"
    try:
        resp = _http_head(url)
    except Exception as e:  # network error -> data, not crash
        return f"ERROR: request failed: {str(e)[:120]}"
    if resp.status_code in (404, 410):
        return f"NOT_FOUND (status={resp.status_code})"
    if 200 <= resp.status_code < 400:
        return "EXISTS"
    return f"ERROR: unexpected status={resp.status_code}"


def _check_oci(ref: str) -> str:
    body = ref[len("oci://"):] if ref.startswith("oci://") else ref
    if "@" in body:
        repo_part, tag = body.split("@", 1)
    elif ":" in body.split("/", 1)[-1]:
        repo_part, tag = body.rsplit(":", 1)
    else:
        repo_part, tag = body, "latest"
    if "/" not in repo_part:
        return "ERROR: malformed OCI ref (expected registry/repo)"
    registry, repo = repo_part.split("/", 1)
    if _host_is_blocked(registry.split(":")[0]):
        return "ERROR: blocked registry host"
    url = f"https://{registry}/v2/{repo}/manifests/{tag}"
    accept = ("application/vnd.oci.image.index.v1+json,"
              "application/vnd.oci.image.manifest.v1+json,"
              "application/vnd.docker.distribution.manifest.v2+json")
    try:
        resp = _oci_head(url, headers={"Accept": accept})
        if resp.status_code == 401:
            token = _oci_anon_token(resp, registry, repo)
            if token is None:
                return "ERROR: registry requires non-anonymous auth"
            resp = _oci_head(url, headers={"Accept": accept, "Authorization": f"Bearer {token}"})
    except Exception as e:
        return f"ERROR: registry request failed: {str(e)[:120]}"
    if resp.status_code == 404:
        return "NOT_FOUND (status=404)"
    if 200 <= resp.status_code < 300:
        return "EXISTS"
    return f"ERROR: unexpected status={resp.status_code}"


def _oci_anon_token(resp_401, registry: str, repo: str):
    import httpx
    www = resp_401.headers.get("Www-Authenticate", "")
    if "Bearer" not in www:
        return None
    parts = {}
    for kv in www[www.find("Bearer") + 6:].split(","):
        if "=" in kv:
            k, v = kv.strip().split("=", 1)
            parts[k] = v.strip('"')
    realm = parts.get("realm", "")
    if not realm or _host_is_blocked(urlparse(realm).hostname or ""):
        return None
    params = {k: v for k, v in parts.items() if k in ("service", "scope")}
    if "scope" not in params:
        params["scope"] = f"repository:{repo}:pull"
    r = httpx.get(realm, params=params, timeout=_TIMEOUT)
    if r.status_code != 200:
        return None
    return r.json().get("token") or r.json().get("access_token")


def check_reference_exists(ref: str) -> str:
    scheme = urlparse(ref).scheme or ("oci" if "/" in ref and ":" in ref else "")
    if ref.startswith("oci://") or (scheme == "oci"):
        return _check_oci(ref)
    if scheme not in _ALLOWED_SCHEMES:
        return f"ERROR: blocked or missing scheme '{scheme}'"
    return _check_http(ref)
