#!/usr/bin/env bash
# lib/ecc.sh — Everything Claude Code + ccg-workflow

ECC_REPO="https://github.com/affaan-m/everything-claude-code.git"
ECC_DIR="$HOME/everything-claude-code"

step_ecc() {
  # ── Clone / update ────────────────────────────────────────────
  step "Cloning / updating ECC"
  if [ -d "$ECC_DIR/.git" ]; then
    info "ECC đã có tại $ECC_DIR — pulling..."
    run "git -C '$ECC_DIR' pull --quiet --ff-only" \
      || warn "git pull failed — sẽ dùng version hiện tại"
    ok "ECC up to date"
  else
    run "git clone --depth=1 '$ECC_REPO' '$ECC_DIR'"
    ok "ECC cloned → $ECC_DIR"
  fi

  # ── Run install.sh ────────────────────────────────────────────
  step "ECC install.sh --target $TARGET $LANGUAGES"

  if [ ! -f "$ECC_DIR/install.sh" ]; then
    warn "install.sh not found in $ECC_DIR — skipping"
    return 1
  fi

  if [ "${DRY_RUN:-false}" = true ]; then
    info "[dry-run] cd $ECC_DIR && bash install.sh --target $TARGET $LANGUAGES"
  else
    (
      cd "$ECC_DIR"
      bash install.sh --target "$TARGET" $LANGUAGES
    )
  fi
  ok "ECC rules + agents + skills + hooks installed (target=$TARGET, langs=$LANGUAGES)"

  # ── Plugin (chỉ khi target là claude) ─────────────────────────
  if [ "$TARGET" = "claude" ] && has claude; then
    step "ECC Claude plugin"
    if ask "Cài ECC plugin qua Claude marketplace?"; then
      run "claude plugin marketplace add affaan-m/everything-claude-code 2>/dev/null || true"
      if run "claude plugin install everything-claude-code@everything-claude-code 2>/dev/null"; then
        ok "ECC plugin installed"
      else
        warn "ECC plugin: có thể đã cài — bỏ qua"
      fi
    fi
  elif [ "$TARGET" = "claude" ] && ! has claude; then
    warn "Claude Code chưa cài — bỏ qua plugin"
    info "Cài Claude Code: curl -fsSL https://claude.ai/install.sh | bash"
  fi

  # ── ccg-workflow runtime ───────────────────────────────────────
  step "ccg-workflow (cho /multi-* commands)"
  if ask "Cài ccg-workflow runtime?"; then
    if run "npx ccg-workflow 2>&1"; then
      ok "ccg-workflow initialized"
    else
      warn "ccg-workflow failed — thử lại sau: npx ccg-workflow"
    fi
  else
    info "Bỏ qua. Cài sau nếu cần: npx ccg-workflow"
  fi
}