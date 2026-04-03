# Token Optimization

## Model selection
Sonnet: 90% tasks — CRUD, components, fixes, tests
Opus khi: architectural decisions, security review, task span 5+ files, debug khó

## Tiết kiệm token
- Dùng .claude/graph/index.md thay vì quét src/
- Load đúng file liên quan, không load hết
- /fork cho task không liên quan song song
- Commit nhỏ — context window reset tự nhiên
- Truncate output dài: "chỉ 20 dòng đầu"

## Stop hook là EXCLUSIVE
UserPromptSubmit: chạy mỗi message — làm chậm mọi prompt
Stop: chạy 1 lần cuối session — dùng cái này

## Session timer
ccstart = timer 5h + Claude cùng lúc
/wrap-session khi còn 10 phút
