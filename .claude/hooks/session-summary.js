#!/usr/bin/env node
// Stop hook — tự động prompt Claude tạo session summary

const fs = require('fs')
const path = require('path')

const now = new Date()
const ts = now.toISOString().slice(0, 16).replace('T', '-').replace(':', '')

const sessionDirs = [
  path.join(process.cwd(), '.claude', 'sessions'),
  path.join(process.env.HOME || '', '.claude', 'sessions')
]

// Tạo thư mục nếu chưa có
for (const dir of sessionDirs.slice(0, 1)) {
  fs.mkdirSync(dir, { recursive: true })
}

const outFile = path.join(sessionDirs[0], `${ts}.md`)

// Inject prompt vào conversation để Claude tạo summary
process.stdout.write(JSON.stringify({
  type: 'inject',
  content: `Tạo session summary và lưu vào ${outFile}:
# Session: ${now.toLocaleString('vi-VN')}
## Đã hoàn thành
## Đang dở
## Bước tiếp theo
## Quyết định quan trọng
## Files đã thay đổi
## Gotchas`
}))
