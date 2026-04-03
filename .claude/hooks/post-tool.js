#!/usr/bin/env node
// PostToolUse hook — audit log

const fs = require('fs')
const path = require('path')

const input = JSON.parse(process.stdin.read() || '{}')
const logDir = path.join(process.cwd(), '.claude')
const logFile = path.join(logDir, 'audit.log')

try {
  fs.mkdirSync(logDir, { recursive: true })
  const entry = JSON.stringify({
    ts: new Date().toISOString(),
    tool: input.tool,
    input: JSON.stringify(input.input || {}).slice(0, 200),
    ok: !input.error
  })
  fs.appendFileSync(logFile, entry + '\n')
} catch (_) {
  // Audit log không block tool execution
}
