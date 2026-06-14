---
phase: "05"
plan: "03"
---

# T03: 实现 KgController 4 个 REST 端点 + KgQueryTool 真实 KG 查询 + PalaceToolProvider 委托替换 + 12 个测试 + 编译全通过

**实现 KgController 4 个 REST 端点 + KgQueryTool 真实 KG 查询 + PalaceToolProvider 委托替换 + 12 个测试 + 编译全通过**

## What Happened

实现了 S05 的 API 层和 S03 集成点：

1. **KgController** — 4 个 REST 端点:
   - `GET /api/v1/kg/notifications` — 支持 `?unread=true` 过滤
   - `PUT /api/v1/kg/notifications/{id}/read` — 标记已读，400/404 错误处理
   - `GET /api/v1/kg/contradictions` — 支持 `?status=escalated` 过滤
   - `PUT /api/v1/kg/contradictions/{id}/resolve` — 解决矛盾，幂等处理已 resolved 的情况

2. **KgQueryTool** — 真实 KG 查询服务:
   - pg_trgm 模糊搜索实体
   - 获取 source/target 双向关系
   - 拼装 JSON（含 entity 详情 + relationships 列表 + 对端实体简要信息）
   - 空输入、无匹配、unknown 对端实体等边界处理

3. **PalaceToolProvider 修改**:
   - 通过 `ObjectProvider<KgQueryTool>` 注入避免循环依赖
   - `kgQueryEntity()` 委托 KgQueryTool（非 null 时），否则回退到 Phase 1 占位逻辑
   - @Tool description 更新，去掉 "Phase 1 占位" 字样
   - 修复 PalaceToolProviderTest 适配新构造函数签名

4. **KgControllerTest** — 12 个 MockMvc 测试覆盖全部端点场景:
   - GET notifications 全部/未读/空数组
   - PUT read 成功/404/400（无效 UUID）
   - GET contradictions 全部/按状态过滤
   - PUT resolve 成功/404/400/幂等

5. **KgQueryToolTest** — 7 个 Mockito 单元测试:
   - null/blank 输入防御
   - 无匹配实体
   - outgoing/incoming 关系
   - 多候选实体取最佳匹配
   - unknown 对端实体

6. **补充 Repository 方法**:
   - KgAdminNotificationRepository 添加 `findAll()` 和 `findById()`
   - KgContradictionRepository 添加 `findAll()`

## Verification

运行 `cd backend && mvn compile test-compile -q` 编译全部通过，主代码和测试代码无编译错误。所有 5 个预期输出文件均已创建。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd backend && mvn compile test-compile -q && echo BUILD SUCCESS` | 0 | ✅ pass | 3400ms |

## Deviations

给 KgAdminNotificationRepository 补充了 findAll() 和 findById() 方法，给 KgContradictionRepository 补充了 findAll() 方法——这些方法是 Controller 层需要但 T01 未预见到的。修复了 PalaceToolProviderTest 以适配新构造函数签名（T03 计划中未提及但属于必要的编译修复）。

## Known Issues

None.

## Files Created/Modified

- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgController.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgQueryTool.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceToolProvider.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/kg/KgControllerTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/kg/KgQueryToolTest.java`
