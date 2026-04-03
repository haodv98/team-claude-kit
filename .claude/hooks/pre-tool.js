#!/usr/bin/env node
// PreToolUse hook — block lệnh nguy hiểm

const input = JSON.parse(process.stdin.read() || '{}')
const { tool, input: toolInput } = input

const DANGEROUS = [
  'rm -rf', 'rm -r /', 'DROP TABLE', 'DROP DATABASE',
  'DELETE FROM', '--force', 'git push --force',
  'curl | bash', 'wget | bash', 'eval ', '| eval',
  'chmod 777', '> /dev/sda', 'mkfs'
]

const PROTECTED_PATHS = [
  '.env.production', '.env.prod', 'prisma/migrations',
  '.git/config', '/etc/', '/usr/', '/bin/'
]

if (tool === 'Bash' && toolInput?.command) {
  const cmd = toolInput.command.toLowerCase()

  for (const d of DANGEROUS) {
    if (cmd.includes(d.toLowerCase())) {
      process.stdout.write(JSON.stringify({
        block: true,
        reason: `Lệnh nguy hiểm phát hiện: "${d}". Confirm thủ công trước khi chạy.`
      }))
      process.exit(0)
    }
  }
}

if ((tool === 'FileWrite' || tool === 'FileEdit') && toolInput?.path) {
  for (const p of PROTECTED_PATHS) {
    if (toolInput.path.includes(p)) {
      process.stdout.write(JSON.stringify({
        block: true,
        reason: `Protected path: "${toolInput.path}". Confirm thủ công.`
      }))
      process.exit(0)
    }
  }
}

// Allow
process.stdout.write(JSON.stringify({ block: false }))
