"""Tests for secret redaction. Patterns mirror the existing panel/sanitize.py."""
import pytest
from nemotron_approve.sanitize import sanitize


@pytest.mark.parametrize("input_text,expected_substring,redacted_substring", [
    # URL-embedded credentials
    ("git clone https://user:GHP_SECRET@github.com/foo/bar", "<redacted>@github.com", "GHP_SECRET"),
    ("curl https://admin:hunter2@api.example.com", "<redacted>@api.example.com", "hunter2"),
    # Token flags
    ("kubectl --token=ABC123 get pods", "--token=<redacted>", "ABC123"),
    ("curl --api-key=SECRET https://api", "--api-key=<redacted>", "SECRET"),
    ("login --password=hunter2", "--password=<redacted>", "hunter2"),
    # Authorization header
    ("curl -H 'Authorization: Bearer tok_abc123' https://api", "Bearer <redacted>", "tok_abc123"),
    ("curl -H 'Authorization: token_abc123' https://api", "Authorization: <redacted>", "token_abc123"),
])
def test_sanitize_redacts_credentials(input_text, expected_substring, redacted_substring):
    out = sanitize(input_text)
    assert expected_substring in out
    assert redacted_substring not in out


@pytest.mark.parametrize("input_text", [
    "ls -la /tmp",
    "kubectl get pods",
    "git status",
    "echo hello world",
    # Negative: --tokenize is not --token=
    "rustc --tokenize foo.rs",
])
def test_sanitize_does_not_overredact(input_text):
    """Sanitizer must NOT modify text that has no credential-shaped patterns."""
    out = sanitize(input_text)
    assert out == input_text


def test_sanitize_handles_empty():
    assert sanitize("") == ""


def test_sanitize_handles_multiline():
    inp = "line1 --token=ABC\nline2 --password=XYZ"
    out = sanitize(inp)
    assert "ABC" not in out
    assert "XYZ" not in out
