#!/usr/bin/env bash
# post-edit-quality.sh — Security pattern detection
# Warns when edited file contains security-sensitive patterns.
# $FILE_PATH is set by Claude Code for Write/Edit PostToolUse events.

FILE="${FILE_PATH:-}"
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0

# Security-sensitive patterns (case-insensitive)
PATTERN='(password|secret|api[_-]?key|jwt|\.sign\(|\.verify\(|bcrypt|crypto\.|encrypt|decrypt|auth[^o]|signin|login\(|permission|acl\b|privilege|role\b|supabase\.auth|prisma\.(user|session|account|token)|\.env\b|getenv\(|process\.env)'

if grep -qiE "$PATTERN" "$FILE" 2>/dev/null; then
  echo ""
  echo "🔐 SECURITY ALERT: $(basename "$FILE") contains security-sensitive patterns."
  echo "   MUST run /security-scan before committing this file."
  echo ""
fi

exit 0
