#!/usr/bin/env bash
# stop-verify.sh — Session-end enforcement checklist
# Runs when Claude session stops. Non-blocking (informational only).

DIRTY=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
TOTAL=$((DIRTY + STAGED))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Session End — Required Checklist"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$TOTAL" -gt 0 ]; then
  echo "  ⚠️  $TOTAL uncommitted change(s) — commit or stash before closing."
fi

echo ""
echo "  □ Update memory/decisions.md with today's decisions"
echo "  □ Run /wrap-session to save session state"
echo "  □ git status — verify clean or staged"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
