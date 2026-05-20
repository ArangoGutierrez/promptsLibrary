"""Nemotron LLM client wrapper. Tests use a fake NIM client stub at the seam."""
import pytest
from unittest.mock import MagicMock
from nemotron_approve.llm_client import NemotronClassifier
from nemotron_approve.verdict import Decision, Category


def make_classifier(client_response_text=None, raises=None):
    """Build a classifier with an injected mock client. The mock's chat()
    method returns the canned text or raises the given exception. Uses
    __new__ to bypass __init__ (which would import nvidia-nat)."""
    classifier = NemotronClassifier.__new__(NemotronClassifier)
    classifier._timeout = 10
    classifier._max_tokens = 512
    classifier._client = MagicMock()
    if raises:
        classifier._client.chat.side_effect = raises
    else:
        classifier._client.chat.return_value = client_response_text
    return classifier


def test_classify_parses_well_formed_allow():
    response = "DECISION: allow\nCATEGORY: local_write\nRATIONALE: npm install in cwd"
    classifier = make_classifier(client_response_text=response)
    v = classifier.classify("Bash", {"command": "npm install"}, {"cwd": "/x"})
    assert v.decision == Decision.ALLOW
    assert v.category == Category.LOCAL_WRITE
    assert "npm install" in v.rationale


def test_classify_parses_well_formed_ask():
    response = "DECISION: ask\nCATEGORY: mutating\nRATIONALE: prod cluster"
    classifier = make_classifier(client_response_text=response)
    v = classifier.classify("Bash", {"command": "kubectl apply"}, {"cwd": "/x"})
    assert v.decision == Decision.ASK
    assert v.category == Category.MUTATING


def test_classify_malformed_response_falls_back_to_ask():
    classifier = make_classifier(client_response_text="this is not the right format")
    v = classifier.classify("Bash", {"command": "x"}, {})
    assert v.decision == Decision.ASK
    assert "malformed" in v.rationale.lower()


def test_classify_empty_response_falls_back_to_ask():
    classifier = make_classifier(client_response_text="")
    v = classifier.classify("Bash", {"command": "x"}, {})
    assert v.decision == Decision.ASK
    assert "empty" in v.rationale.lower()


def test_classify_timeout_falls_back_to_ask():
    classifier = make_classifier(raises=TimeoutError("simulated timeout"))
    v = classifier.classify("Bash", {"command": "x"}, {})
    assert v.decision == Decision.ASK
    assert "timeout" in v.rationale.lower()


def test_classify_http_error_falls_back_to_ask():
    import urllib.error
    err = urllib.error.HTTPError("url", 503, "service unavailable", {}, None)
    classifier = make_classifier(raises=err)
    v = classifier.classify("Bash", {"command": "x"}, {})
    assert v.decision == Decision.ASK
    assert "http" in v.rationale.lower() or "error" in v.rationale.lower()
