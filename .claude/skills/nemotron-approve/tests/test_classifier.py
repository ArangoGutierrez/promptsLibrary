"""Three-lane orchestration: Lane A -> Lane B -> Lane C -> Lane B re-check after C allow."""
import pytest
from unittest.mock import MagicMock
from nemotron_approve.classifier import Classifier
from nemotron_approve.verdict import Verdict, Decision, Category, Lane


@pytest.fixture
def fake_llm():
    """Mock LLM classifier."""
    llm = MagicMock()
    return llm


@pytest.fixture
def fake_cache():
    cache = MagicMock()
    cache.get.return_value = None  # default: cache miss
    return cache


def make_clf(fake_llm, fake_cache):
    return Classifier(llm_client=fake_llm, cache=fake_cache)


def test_lane_a_match_returns_allow_without_llm(fake_llm, fake_cache):
    clf = make_clf(fake_llm, fake_cache)
    v = clf.classify("Bash", {"command": "kubectl get pods"}, {})
    assert v.decision == Decision.ALLOW
    assert v.lane == Lane.A
    fake_llm.classify.assert_not_called()


def test_lane_b_match_returns_ask_without_llm(fake_llm, fake_cache):
    clf = make_clf(fake_llm, fake_cache)
    v = clf.classify("Bash", {"command": "rm -rf /tmp/foo"}, {})
    assert v.decision == Decision.ASK
    assert v.lane == Lane.B
    fake_llm.classify.assert_not_called()


def test_lane_c_allow_passes_through(fake_llm, fake_cache):
    fake_llm.classify.return_value = Verdict(
        Decision.ALLOW, Category.LOCAL_WRITE, "kind context", Lane.C
    )
    clf = make_clf(fake_llm, fake_cache)
    v = clf.classify("Bash", {"command": "kubectl apply -f x.yaml"}, {})
    assert v.decision == Decision.ALLOW
    assert v.lane == Lane.C
    fake_llm.classify.assert_called_once()


def test_lane_c_allow_but_lane_b_recheck_catches(fake_llm, fake_cache):
    """LLM says allow, but Lane B re-check finds a DENY pattern -> override to ASK.
    This is the prompt-injection defense."""
    fake_llm.classify.return_value = Verdict(
        Decision.ALLOW, Category.READ, "I think this is safe", Lane.C
    )
    clf = make_clf(fake_llm, fake_cache)
    # Bypass Lane B by calling _lane_c_with_recheck directly. This tests the
    # re-check fallback that catches a prompt-injected LLM allow.
    v = clf._lane_c_with_recheck("Bash", {"command": "x; rm -rf /tmp"}, {})
    assert v.decision == Decision.ASK
    assert v.lane == Lane.B  # re-check override marks lane as B


def test_lane_c_ask_passes_through(fake_llm, fake_cache):
    fake_llm.classify.return_value = Verdict(
        Decision.ASK, Category.MUTATING, "prod cluster", Lane.C
    )
    clf = make_clf(fake_llm, fake_cache)
    v = clf.classify("Bash", {"command": "kubectl apply -f x.yaml"}, {})
    assert v.decision == Decision.ASK
    assert v.lane == Lane.C


def test_cache_hit_skips_llm(fake_llm, fake_cache):
    cached = Verdict(Decision.ALLOW, Category.LOCAL_WRITE, "from cache", Lane.CACHE)
    fake_cache.get.return_value = cached
    clf = make_clf(fake_llm, fake_cache)
    v = clf.classify("Bash", {"command": "kubectl apply -f x.yaml"}, {})
    assert v.lane == Lane.CACHE
    fake_llm.classify.assert_not_called()


def test_no_llm_client_falls_back_to_ask_on_gray_zone(fake_cache):
    """If LLM is unavailable (None), gray-zone classification -> ASK."""
    clf = Classifier(llm_client=None, cache=fake_cache)
    v = clf.classify("Bash", {"command": "kubectl apply -f x.yaml"}, {})
    assert v.decision == Decision.ASK
