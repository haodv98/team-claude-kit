# Team Workflows

## Git strategy
main ← staging ← dev/[tên]/[task]
Mỗi người một worktree riêng. Rebase thay merge.

## Worktree workflow
git worktree add ../project-[task] dev/[tên]/[task]
cd ../project-[task] && ccstart

## Trước khi PR
/code-review (invoke code-reviewer + verifier agents)
git fetch origin && git rebase origin/main
git push origin dev/[tên]/[task]

## Schema/API change
→ Dừng, invoke db-migration-advisor agent
→ Confirm team qua Slack #dev
→ Không tự tiến hành

## Sync kit (mỗi thứ Hai)
ccsync

## Đóng góp vào kit
ccsync --push
→ Chọn file muốn share → commit vào kit
