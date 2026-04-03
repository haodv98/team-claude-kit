# Team Claude Kit

Claude Code configuration, playbook, và tooling chuẩn cho team.
Meta repo — source of truth. Mỗi project reference từ đây.

## Onboard (15 phút)

```bash
# 1. Clone
git clone git@github.com:[org]/team-claude-kit.git ~/team-claude-kit

# 2. Cài Claude Code
npm install -g @anthropic-ai/claude-code && claude login

# 3. Run install
cd ~/team-claude-kit && bash scripts/install.sh
source ~/.zshrc

# 4. Superpowers (trong Claude Code session)
# /plugin marketplace add obra/superpowers-marketplace
# /plugin install superpowers@superpowers-marketplace
```

## Hàng ngày

```bash
ccstart          # mở Claude + timer 5h
/using-superpowers
/onboard         # lần đầu vào project
/new-feature     # bắt đầu feature mới
/wrap-session    # trước khi đóng
ccsync           # sync kit (mỗi thứ Hai)
```

## Đóng góp vào kit

```bash
ccsync --push   # chọn file → copy vào kit → commit + push
```

## Cấu trúc

```
claude/      — agents, skills, commands, hooks, settings
playbook/    — hướng dẫn sử dụng Claude hiệu quả
scripts/     — install, sync, create-project, session-timer
templates/   — project starters
```

## Liên hệ

Slack: #dev-tools
