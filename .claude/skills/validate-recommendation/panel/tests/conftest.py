"""Shared pytest fixtures for panel tests."""
from pathlib import Path
import pytest

SKILL_DIR = Path(__file__).resolve().parent.parent.parent  # .../validate-recommendation/
FIXTURES_DIR = SKILL_DIR / "fixtures"


@pytest.fixture
def fixtures_dir() -> Path:
    """Path to the validate-recommendation skill's fixtures directory.

    Used by aggregate-parity tests that reuse the same fixtures as
    aggregate_test.sh (da_hold.txt, da_overturn_b.txt, etc).
    """
    return FIXTURES_DIR


# Appended in Phase 3a — points at the real personas/ directory shipped with the skill.


@pytest.fixture
def personas_dir() -> Path:
    """Path to the real personas/ directory shipped next to panel/."""
    return Path(__file__).resolve().parent.parent.parent / "personas"
