#!/usr/bin/env bash
# day.sh — stateless daily-flow orienter. Prints the lifecycle with the
# best-guess current stage and one recommended next action. Exit 0 always.
# Pure logic (classify_stage/recommend) is unit-tested in day_test.sh.
set -o pipefail

# classify_stage <has_goal> <has_spec> <has_plan> <tree_dirty> <work_committed>
# Each arg is "1" or "0". Echoes a stage id.
classify_stage() {
  local has_goal="$1" has_spec="$2" has_plan="$3" tree_dirty="$4" work_committed="$5"
  [ "$has_goal" != "1" ] && { echo "no-goal"; return; }
  [ "$has_spec" != "1" ] && { echo "needs-brainstorm"; return; }
  [ "$has_plan" != "1" ] && { echo "needs-plan"; return; }
  [ "$tree_dirty" = "1" ] && { echo "mid-impl"; return; }
  [ "$work_committed" = "1" ] && { echo "needs-review"; return; }
  echo "ready-to-impl"
}

# recommend <stage> — echoes the single next action.
recommend() {
  case "$1" in
    no-goal)          echo "Set today's goal:   /goal" ;;
    needs-brainstorm) echo "Explore the idea:   superpowers:brainstorming" ;;
    needs-plan)       echo "Write the plan:     superpowers:writing-plans" ;;
    ready-to-impl)    echo "Start building:     superpowers:test-driven-development" ;;
    mid-impl)         echo "Continue TDD; mind the verification pair (Coding↔Unit, Design↔Integration, Requirements↔Acceptance)" ;;
    needs-review)     echo "Review then ship:   requesting-code-review → superpowers:finishing-a-development-branch" ;;
    *)                echo "Unknown stage: $1" ;;
  esac
}

# detect_signals — best-effort, prints "has_goal has_spec has_plan tree_dirty work_committed".
# Heuristic glue, not unit-tested (covered by smoke test + shellcheck).
detect_signals() {
  local goal_dir="${HOME}/.claude/audit/session-goals" today has_goal=0 has_spec=0 has_plan=0 tree_dirty=0 work_committed=0
  if [ -n "${CLAUDE_SESSION_ID:-}" ] && [ -f "${goal_dir}/${CLAUDE_SESSION_ID}.md" ]; then
    has_goal=1
  elif [ -d "$goal_dir" ] && [ -n "$(ls -A "$goal_dir" 2>/dev/null)" ]; then
    has_goal=1
  fi
  today="$(date +%Y-%m-%d)"
  ls docs/superpowers/specs/"${today}"-* >/dev/null 2>&1 && has_spec=1
  ls docs/superpowers/plans/"${today}"-* >/dev/null 2>&1 && has_plan=1
  [ -n "$(git status --porcelain 2>/dev/null)" ] && tree_dirty=1
  if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    git log --oneline origin/main..HEAD -- . ':(exclude)docs/**' 2>/dev/null | grep -q . && work_committed=1
  fi
  echo "$has_goal $has_spec $has_plan $tree_dirty $work_committed"
}

main() {
  local sig stage
  sig="$(detect_signals)"
  # shellcheck disable=SC2086
  stage="$(classify_stage $sig)"
  echo "Daily flow:  goal → brainstorm → plan → execute(TDD) → review → finish"
  echo "Likely here: ${stage}"
  echo "Next:        $(recommend "$stage")"
  echo "(stateless best-guess from goal file + today's spec/plan + git state)"
}

# Only run main when executed directly, not when sourced by the test.
[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
