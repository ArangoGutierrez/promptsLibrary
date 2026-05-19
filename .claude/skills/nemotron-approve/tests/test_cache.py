"""Cache behavior: hit, miss, expired, corrupt-file recovery, key derivation."""
import json
import time
import pytest
from pathlib import Path
from nemotron_approve.cache import VerdictCache
from nemotron_approve.verdict import Verdict, Decision, Category, Lane


@pytest.fixture
def cache(tmp_path):
    return VerdictCache(tmp_path / "cache.json", ttl_seconds=3600)


@pytest.fixture
def sample_verdict():
    return Verdict(decision=Decision.ALLOW, category=Category.READ,
                   rationale="test", lane=Lane.C)


def test_cache_miss_returns_none(cache):
    assert cache.get("Bash", {"command": "kubectl get pods"}) is None


def test_cache_hit_returns_stored_verdict(cache, sample_verdict):
    cache.put("Bash", {"command": "kubectl get pods"}, sample_verdict)
    got = cache.get("Bash", {"command": "kubectl get pods"})
    assert got.decision == Decision.ALLOW
    assert got.category == Category.READ
    assert got.rationale == "test"
    # Lane on read is CACHE, not C
    assert got.lane == Lane.CACHE


def test_cache_different_inputs_dont_collide(cache, sample_verdict):
    cache.put("Bash", {"command": "kubectl get pods"}, sample_verdict)
    assert cache.get("Bash", {"command": "kubectl get nodes"}) is None
    assert cache.get("WebFetch", {"command": "kubectl get pods"}) is None


def test_cache_expired_returns_none(tmp_path, sample_verdict):
    cache = VerdictCache(tmp_path / "cache.json", ttl_seconds=0)
    cache.put("Bash", {"command": "kubectl get pods"}, sample_verdict)
    time.sleep(0.01)
    assert cache.get("Bash", {"command": "kubectl get pods"}) is None


def test_cache_corrupt_file_returns_none(tmp_path):
    cache_path = tmp_path / "cache.json"
    cache_path.write_text("not json {{{")
    cache = VerdictCache(cache_path, ttl_seconds=3600)
    # Should not crash
    assert cache.get("Bash", {"command": "kubectl get pods"}) is None


def test_cache_persists_across_instances(tmp_path, sample_verdict):
    cache1 = VerdictCache(tmp_path / "cache.json", ttl_seconds=3600)
    cache1.put("Bash", {"command": "kubectl get pods"}, sample_verdict)

    cache2 = VerdictCache(tmp_path / "cache.json", ttl_seconds=3600)
    got = cache2.get("Bash", {"command": "kubectl get pods"})
    assert got is not None
    assert got.decision == Decision.ALLOW
