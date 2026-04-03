#!/usr/bin/env node
// SessionStart hook — inject graph + session memory vào context

const fs = require('fs')
const path = require('path')

const GRAPH_DIR = path.join(process.cwd(), '.claude', 'graph')
const SESSION_DIRS = [
  path.join(process.cwd(), '.claude', 'sessions'),
  path.join(process.env.HOME || '', '.claude', 'sessions')
]

function isGraphFresh(maxHours = 24) {
  const idx = path.join(GRAPH_DIR, 'index.md')
  if (!fs.existsSync(idx)) return false
  const age = (Date.now() - fs.statSync(idx).mtimeMs) / 3600000
  return age < maxHours
}

function getLatestSession() {
  for (const dir of SESSION_DIRS) {
    if (!fs.existsSync(dir)) continue
    const files = fs.readdirSync(dir).filter(f => f.endsWith('.md')).sort().reverse()
    if (files.length === 0) continue
    const fpath = path.join(dir, files[0])
    const ageH = (Date.now() - fs.statSync(fpath).mtimeMs) / 3600000
    if (ageH > 48) continue
    const content = fs.readFileSync(fpath, 'utf-8')
    return { path: fpath, content, ageH: Math.round(ageH) }
  }
  return null
}

function extractKeyParts(content) {
  const want = ['## Đang dở', '## Bước tiếp theo', '## Quyết định quan trọng', '## Gotchas']
  const lines = content.split('\n')
  const out = []
  let inSection = false
  for (const line of lines) {
    if (want.some(s => line.startsWith(s))) { inSection = true; out.push(line) }
    else if (inSection && line.startsWith('## ')) inSection = false
    else if (inSection) out.push(line)
  }
  return out.join('\n')
}

const parts = []

if (isGraphFresh()) {
  parts.push('## Codebase Graph (đã index — không cần quét lại src/)')
  parts.push(fs.readFileSync(path.join(GRAPH_DIR, 'index.md'), 'utf-8'))
} else if (fs.existsSync(GRAPH_DIR)) {
  parts.push('## Codebase Graph')
  parts.push('⚠️  Graph cũ hơn 24h. Chạy: pnpm graph để rebuild.')
}

const session = getLatestSession()
if (session) {
  parts.push(`\n## Session gần nhất (${session.ageH}h trước)`)
  parts.push(extractKeyParts(session.content))
}

const memory = path.join(process.cwd(), '.claude', 'memory.md')
if (fs.existsSync(memory)) {
  parts.push('\n## Project Memory')
  parts.push(fs.readFileSync(memory, 'utf-8').slice(0, 2000))
}

if (parts.length > 0) {
  parts.push('\n## Reminder')
  parts.push('- Dùng graph để navigate, không đọc từng file')
  parts.push('- use context7 khi làm việc với thư viện')
  parts.push('- Báo complexity trước khi bắt đầu task lớn')
  process.stdout.write(JSON.stringify({ type: 'context', content: parts.join('\n') }))
}
