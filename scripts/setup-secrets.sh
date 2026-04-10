#!/usr/bin/env bash
# scripts/setup-secrets.sh — Wizard setup API keys lần đầu
# Chạy độc lập: bash scripts/setup-secrets.sh

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/secrets.sh"

interactive_setup_secrets

echo ""
info "Xong! Chạy lại bootstrap để áp dụng:"
echo "  bash bootstrap.sh --yes"