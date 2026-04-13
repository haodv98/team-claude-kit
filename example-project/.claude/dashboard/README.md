# To-Do Dashboard Setup

## 1. Supabase
1. Tạo project tại https://app.supabase.com
2. Vào SQL Editor → chạy `supabase-migration.sql`
3. Copy `SUPABASE_URL` và `SUPABASE_ANON_KEY` từ Settings → API

## 2. Environment
Thêm vào `/Users/haodv/Documents/AI Agent/team-claude-kit/example-project/.env.local`:
```
NEXT_PUBLIC_SUPABASE_URL=https://[project].supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
```

## 3. Tạo dashboard với Claude Code
Mở Claude Code trong project và gửi prompt sau:

```
Build a real-time to-do dashboard using Next.js and Supabase.
The todos table already exists with fields: id, title, status, priority, assigned_agent, updated_at.
Enable Supabase Realtime so the UI updates live via websockets — no refresh needed.
When an agent completes a task, it should update the status directly in Supabase and the dashboard reflects it instantly.
Style: dark, minimal, clean.
Read memory/preferences.md for additional coding preferences.
```

## 4. Update status từ Claude Code
```typescript
// Agent tự update status
const { error } = await supabase
  .from('todos')
  .update({ status: 'done', assigned_agent: 'claude' })
  .eq('id', todoId)
```
