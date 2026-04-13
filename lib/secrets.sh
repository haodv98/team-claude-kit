#!/usr/bin/env bash

# lib/secrets.sh — Quản lý API keys an toàn
#
# Thứ tự ưu tiên khi load secrets:
#   1. Biến môi trường đã có sẵn (CI/CD, Codespaces...)
#   2. macOS Keychain (nếu đang chạy trên macOS)
#   3. File .env.local trong thư mục kit (gitignored)
#   4. Cảnh báo nếu vẫn thiếu

# ─── Load từ file .env.local (fallback an toàn) ─────────────────
# File này KHÔNG được commit lên git (.gitignore đã cover)
load_env_file() {
  local env_file="$SCRIPT_DIR/.env.local"

  if [[ -f "$env_file" ]]; then
    info "Loading secrets từ $env_file"
    # Đọc từng dòng, bỏ qua comment và dòng rỗng
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
      # Chỉ export nếu biến chưa có sẵn trong môi trường
      local key="${line%%=*}"
      if [[ -z "${!key:-}" ]]; then
        export "$line"
      fi
    done < "$env_file"
  fi
}

# ─── macOS Keychain helper ───────────────────────────────────────
keychain_get() {
  local key="$1"
  security find-generic-password -a "$USER" -s "team-claude-kit-$key" -w 2>/dev/null || echo ""
}

keychain_set() {
  local key="$1" value="$2"
  security add-generic-password \
    -a "$USER" \
    -s "team-claude-kit-$key" \
    -w "$value" \
    -U 2>/dev/null
}

# ─── Load từ macOS Keychain ──────────────────────────────────────
load_keychain_secrets() {
  [[ "$(uname)" != "Darwin" ]] && return 0

  local tokens=("GITHUB_PERSONAL_ACCESS_TOKEN" "SENTRY_TOKEN" "FIGMA_TOKEN" "BACKLOG_DOMAIN" "BACKLOG_API_KEY")
  for token in "${tokens[@]}"; do
    if [[ -z "${!token:-}" ]]; then
      local val
      val="$(keychain_get "$token")"
      if [[ -n "$val" ]]; then
        export "$token=$val"
        info "Loaded $token từ Keychain"
      fi
    fi
  done
}

# ─── Kiểm tra và cảnh báo nếu thiếu token ───────────────────────
check_required_secrets() {
  local warn_tokens=(
    "GITHUB_PERSONAL_ACCESS_TOKEN:GitHub MCP"
    "SENTRY_TOKEN:Sentry MCP"
    "FIGMA_TOKEN:Figma MCP"
    "BACKLOG_DOMAIN:Backlog MCP"
    "BACKLOG_API_KEY:Backlog MCP"
  )

  local missing_any=false
  for entry in "${warn_tokens[@]}"; do
    local var="${entry%%:*}"
    local label="${entry##*:}"
    if [[ -z "${!var:-}" ]]; then
      warn "$label sẽ bị skip (thiếu $var)"
      missing_any=true
    fi
  done

  if [[ "$missing_any" == true ]]; then
    echo ""
    info "Cách thêm secrets (chọn 1 trong 2):"
    echo ""
    echo "  [Khuyến nghị] Lưu vào .env.local:"
    echo "    echo 'GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...' >> $SCRIPT_DIR/.env.local"
    echo ""
    if [[ "$(uname)" == "Darwin" ]]; then
      echo "  [macOS Keychain] An toàn hơn:"
      echo "    bash $SCRIPT_DIR/scripts/setup-secrets.sh"
      echo ""
    fi
    echo "  ⚠️  KHÔNG thêm vào ~/.zshrc hay ~/.bashrc dưới dạng plaintext"
    echo ""
  fi
}

# ─── Interactive setup secrets (gọi từ scripts/setup-secrets.sh) ─
interactive_setup_secrets() {
  echo ""
  header "Setup API Keys"
  echo "Các token sẽ được lưu vào .env.local (KHÔNG commit lên git)."

  if [[ "$(uname)" == "Darwin" ]]; then
    echo "Hoặc lưu vào macOS Keychain nếu muốn bảo mật hơn."
    echo ""
    prompt_yn "Lưu vào macOS Keychain thay vì .env.local?" "n"
    USE_KEYCHAIN=$?
  fi

  local env_file="$SCRIPT_DIR/.env.local"
  local tokens=(
    "GITHUB_PERSONAL_ACCESS_TOKEN:GitHub Personal Access Token (scope: repo read, pull_requests read)"
    "SENTRY_TOKEN:Sentry Auth Token (scope: project:read, event:read)"
    "FIGMA_TOKEN:Figma Personal Token (scope: File content read)"
    "BACKLOG_DOMAIN:Backlog domain đầy đủ (VD: yourteam.backlog.com)"
    "BACKLOG_API_KEY:Backlog API Key (Settings → API → Generate API Key)"
    "SLACK_WEBHOOK_URL:Slack Webhook URL (cho morning briefing)"
  )

  for entry in "${tokens[@]}"; do
    local var="${entry%%:*}"
    local label="${entry##*:}"
    echo ""
    echo "$label"
    echo -n "  Nhập $var (Enter để skip): "
    read -rs val
    echo ""
    [[ -z "$val" ]] && continue

    if [[ "${USE_KEYCHAIN:-1}" -eq 0 ]]; then
      keychain_set "$var" "$val"
      info "Đã lưu $var vào Keychain"
    else
      echo "$var=$val" >> "$env_file"
      info "Đã lưu $var vào .env.local"
    fi
  done

  # Đảm bảo .env.local không bị commit
  if ! grep -qxF ".env.local" "$SCRIPT_DIR/.gitignore" 2>/dev/null; then
    echo ".env.local" >> "$SCRIPT_DIR/.gitignore"
    info "Đã thêm .env.local vào .gitignore"
  fi
}

# ─── Entry point — gọi từ bootstrap.sh ──────────────────────────
step_secrets() {
  load_env_file
  load_keychain_secrets
  check_required_secrets
}