#!/usr/bin/env bash
# pre-commit-gate.sh — TDD enforcement
# Blocks git commit if source changes staged without test files.
# Bypass: add [skip-tests] to commit message (docs/config/chore only).
#
# Receives tool input via stdin JSON: {"tool_input": {"command": "git commit ..."}}

INPUT=$(cat)

CMD=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" <<< "$INPUT" 2>/dev/null || echo "")

# Only intercept git commit
echo "$CMD" | grep -qE "^git commit" || exit 0

# Allow [skip-tests] bypass (for docs/config/chore commits only)
if echo "$CMD" | grep -qiE '\[skip-tests\]'; then
  echo "⚠️  TDD gate bypassed via [skip-tests]. Use only for docs/config/chore."
  exit 0
fi

# Check staged changes
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
[ -z "$STAGED" ] && exit 0

# Count source files (exclude test files themselves)
SRC_COUNT=$(echo "$STAGED" \
  | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java|kt|swift|php)$' \
  | grep -vE '\.(test|spec)\.|_test\.|__tests__|/tests?/' \
  | wc -l | tr -d ' ')

# Count test files
TEST_COUNT=$(echo "$STAGED" \
  | grep -E '(\.(test|spec)\.|_test\.|__tests__|/tests?/)' \
  | wc -l | tr -d ' ')

# No source files staged — allow (pure docs/config commit)
[ "$SRC_COUNT" -eq 0 ] && exit 0

if [ "$TEST_COUNT" -eq 0 ]; then
  echo ""
  echo "❌ TDD GATE BLOCKED: $SRC_COUNT source file(s) staged, 0 test files."
  echo ""
  echo "   Required: stage test file(s) alongside source changes."
  echo "   Run: /tdd  → write tests first, then re-commit."
  echo ""
  echo "   Override (docs/config/chore only):"
  echo '   git commit -m "chore: message [skip-tests]"'
  echo ""
  exit 2
fi

echo "✅ TDD gate: $TEST_COUNT test file(s) staged for $SRC_COUNT source file(s)"
exit 0
