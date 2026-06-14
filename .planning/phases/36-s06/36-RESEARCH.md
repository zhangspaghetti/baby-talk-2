# S06 Research: Admin shell chrome compression

## Summary

`AdminLayout.tsx` (216 lines) — `PageContainer`'s `extraContent` prop (lines ~117–166) renders a prominent right-side metadata wall always visible before any work content: (1) username + current module + visible-module count tags, (2) all visible module labels as tags (workspace switcher), (3) all role tags, (4) all permission tags, (5) access + refresh token expiry timestamps.

Secondary issue: `content` prop (lines ~112–116) renders a routing diagnostic paragraph — operator noise.

Fix: **one file, ~40 net lines removed, no interface changes.**

## Recommendation

1. Remove `content={<Typography.Paragraph>...</Typography.Paragraph>}` from `PageContainer`.
2. Remove `extraContent={<Space direction="vertical">...</Space>}` from `PageContainer`.
3. Add collapsed `antd Collapse` panel **after `{children}`** inside `PageContainer` with `defaultActiveKey={[]}` and **`destroyInactivePanel={false}`**.

`destroyInactivePanel={false}` keeps all metadata elements in the DOM even when collapsed, preserving all Playwright test contracts.

## Implementation Landscape

**File:** `admin-web/src/layout/AdminLayout.tsx`

| Location | What changes |
|---|---|
| Lines ~112–116 `content={...}` | Remove entirely |
| Lines ~117–166 `extraContent={...}` | Remove entirely |
| After `{children}` inside `PageContainer` | Add `<Collapse defaultActiveKey={[]} destroyInactivePanel={false} items={[{key:'meta', label:'管理员会话详情', children: <Space>...same metadata...</Space>}]} />` |

Add `Collapse` to antd imports. No other files change. `AdminLayoutProps` interface unchanged.

## Playwright Contract Preservation

| data-testid | Where | Preserved how |
|---|---|---|
| `session-user` | User tag | In collapsed panel (always in DOM) |
| `session-role` | super_admin role tag | In collapsed panel (always in DOM) |
| `workspace-current` | Current module tag | In collapsed panel (always in DOM) |

`workspace-switcher` and `session-permission` are set but not asserted — safe.

## Constraints

- Do NOT replace `admin-web/src/app/theme.ts` tokens
- Must pass `npm run typecheck` — no interface changes means no type risk
- `destroyInactivePanel={false}` is non-negotiable
- Git Bash: `cd /c/code/AI/baby-talk-2`

## Verification

```bash
cd /c/code/AI/baby-talk-2/admin-web && npm run typecheck
```

## Natural Seams

Single task, one file. Remove `content`/`extraContent`, add `Collapse`. antd `Collapse` already in dependency tree. Risk is low.
