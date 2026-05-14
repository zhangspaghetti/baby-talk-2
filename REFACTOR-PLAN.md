# BabyTalk 三端全面重构方案（REFACTOR-PLAN）

> 版本：v1.0（战略蓝图）
> 日期：2026-05-13
> 范围：mobile（Flutter）、backend（Spring Boot 多模块）、admin-web（React + AntD Pro）
> 形态：架构蓝图 + 设计系统规范 + 按端分期路线图 + 风险与发布门禁
> 配套证据：`.gstack/`（最初讨论）、`.ao-output/`（UX/技术债/方案三审）、`.gsd/milestones/M006/slices/S05/`（既有方案）

---

## 0. 目标与不做清单

### 0.1 目标（必须达成）
1. **质感**：三端 UI 达到"精致 + 可信赖"，无 AI slop；admin-web 与 mobile 共享视觉语言（warmPaperAdmin token 体系）。
2. **可维护**：消除"双真相源"，建立单一状态主栈 + bounded context contract；模块边界清晰、可独立演进。
3. **可访问**：mobile / admin-web 关键路径达 WCAG 2.1 AA；支持 `prefers-reduced-motion`、TalkBack/VoiceOver/键盘。
4. **安全合规**：admin-web 撤离 localStorage token；后端补齐 RBAC + 审计 + 儿童语音隐私分级。
5. **发布门禁**：三端建立 lint / format / 单测 / 集成 / e2e / 覆盖率基线 + CI 强制。

### 0.2 不做（明确排除）
- 不做"重写一切"。所有重构以**收口 + 抽取 + 替换**为主，禁止平行新栈。
- 不做产品功能扩张。本计划只服务现有 M006 范围内的体验与质量提升。
- 不做后端框架版本激进升级（除非阻塞 P0 安全/合规）。

---

## 1. 现状诊断（证据汇总）

### 1.1 Mobile（Flutter / Riverpod）— 来自 `.ao-output` UX 审查 + B1 源码抽样
| 维度 | 现状 | 证据 |
|---|---|---|
| UX 综评 | 6.7 / 10（可用但不"精致"） | UX审查 summary.md |
| 核心路径 | 被 Mentor FAB / C3 / 录音 / 庆祝动画稀释 | UX审查 §核心路径 |
| 信息架构 | 4-tab + Drawer + FAB 边界模糊 | UX审查 §IA |
| 无障碍 | 多处未达 WCAG 2.1 AA；缺 TalkBack/VoiceOver 验证；Auto-Flow 无 `prefers-reduced-motion` | UX审查 §a11y |
| 状态层 | ViewModel + Notifier **双真相源** 5–10 处 | 技术债务 P0-① / B1 抽样 |
| 路由 | 路由表 + 深链 + 重入流耦合，缺 contract | B1 抽样 |
| 主题 | theme/token 不统一，部分硬编码 | B1 抽样 |
| 文案 | 中英混杂；术语不一致 | UX审查 §文案 |
| 练习页 | 首屏密度过高 | UX审查 §练习 |

### 1.2 Backend（Spring Boot 多模块 / Maven）— 来自 B2 源码抽样 + 方案评审
| 模块 | 职责 | 主要风险 |
|---|---|---|
| `common` | DTO / events / 基础设施 | 跨模块泄漏的可能性 |
| `db-migration` | Flyway SQL | 缺 10× 容量演练、热点索引未审 |
| `gateway` | Spring Cloud Gateway / CORS / filters | 路由/限流/防滥用未成体系 |
| `admin-api` | 后台 RBAC / 审计 / 运营 | 权限矩阵未文档化、审计落点不全 |
| `app-api` | 端到端业务 + 外部 API | 授权矩阵、token 生命周期、儿童语音隐私分级 |

**方案评审 10 项阻塞**（节选）：启动恢复 / 首页 / Practice dispatch contract、一致性模型、10× 容量与热点链路、查询→数据模型/索引/缓存、外部 API 授权矩阵、token 生命周期、BootCoordinator 改造与 auth state 拆分、敏感数据分类/加密、API 防滥用、儿童语音隐私合规。

### 1.3 Admin-Web（React 18.3.1 + Vite 5.4 + AntD 5.27 + ProComponents 2.8.10）— B3 抽样 + 主对话直读
| Smell | 位置 | 影响 |
|---|---|---|
| #1 `toApiError` 三处重复 | `auth-api.ts:164` / `MentorAuditPage.tsx:570` / `DistributionStatsPage.tsx:649` | 错误处理不一致 |
| #2 token 存 localStorage | `session-store.ts:53-63`（`SESSION_STORAGE_KEY='babytalk.admin.session'`） | XSS 高危 |
| #3 未登录 throw raw Error | `UsersPage.tsx:65-69` | 用户体验差、错误穿透 |
| #4 手写轮询/流分散 | `OverviewPage.tsx:16` / `IngestionSurface.tsx:27` | 缺统一数据层（无 React Query/SWR） |
| #5 缺 ESLint/Prettier/单测 | `package.json` 仅有 `test:e2e` | 发布门禁不完整 |
| #6 大文件超载 | `PalaceRagSurface.tsx`、`UsersPage.tsx`(28KB)、`OverviewPage.tsx`(26KB) | 难以维护与 Code Review |
| #7 内联样式 | `AdminLayout.tsx` `adminSurfaceStyles.page` | 与 token 体系割裂 |
| #8 401 refresh 单飞 | `http-client.ts` `inFlightRefresh` | OK 但与各 client 重复守卫耦合 |
| #9 client-side RBAC 暴露权限码 | `ADMIN_ROUTE_PERMISSION_CODES` | 信息泄露 |
| #10 校验样板重复 | 各 client 重复 `isRecord` / `readRequiredString` / `readEnumValue` | DRY 缺失 |

**e2e 现状**：`admin-web/tests/` 10 个 spec 已覆盖核心页面（access-and-landing / admin-accounts / admin-login / auth-and-rbac / distribution-stats / knowledge-ops / mentor-audit / mentor-distribution-closure / overview-control-plane / users-management）。**仍缺单测、lint、format、覆盖率基线**。

---

## 2. 三端架构蓝图

### 2.1 共同原则
1. **单一真相源**：每个领域状态只在一处可写；其余皆读。
2. **Application / Contract 收口**：UI 层通过 contract 与 application 层通信，禁止跨层私自调用 repository。
3. **模块化单体**：不引入微服务边界；以 Maven 模块 / Flutter feature 包 / admin-web feature 目录强化逻辑边界。
4. **a11y 为一等公民**：在三端建立"无障碍服务层"（焦点管理 / 动效降级 / 语义化标签 / 键盘流）。
5. **门禁分层**：lint → typecheck → unit → integration → e2e → coverage → release，每层均可独立失败。

### 2.2 Mobile 架构
```
mobile/lib/
  app/            ← composition root（路由 + DI + theme 注入；纯壳）
  core/           ← shared kernel（错误模型、a11y 服务、动效降级、i18n）
  design/         ← token + 组件库（Button/Card/Sheet/FAB…，禁止 ad-hoc 样式）
  features/
    home/         ← 单一 Notifier 主栈；ViewModel 仅做投影
    practice/     ← dispatch contract 收口
    mentor/       ← FAB/C3 整合，避免"页中页"
    library/
  data/           ← repository + DTO；不含 UI 状态
  platform/       ← 录音/通知/相机等平台桥接
```
**关键决策**：
- 全量替换"双真相源"——以 Riverpod Notifier 为唯一可写源，原 ViewModel 转为 derived selector。
- 路由表 + 深链 + 重入流抽出 `core/navigation/` 的 contract，受单测覆盖。
- 动效降级与 TalkBack/VoiceOver 在 `core/a11y/` 提供统一 hook。

### 2.3 Backend 架构
保留五模块，强化**契约 + 边界**：
- `common`：仅放无业务依赖的 DTO/events/util；禁止 service 注入。
- `db-migration`：Flyway 版本化；新增 **migration 评审清单**（索引、热点、回滚）。
- `gateway`：补齐限流、防滥用、CORS 收敛、子路径路由文档。
- `admin-api`：建立 **RBAC 矩阵**（角色 × 资源 × 操作），审计落点全覆盖。
- `app-api`：BootCoordinator 拆分为 `auth-state` + `session-bootstrap` + `feature-gates`；token 生命周期文档化；儿童语音隐私分级 + 加密策略。

### 2.4 Admin-Web 架构
```
admin-web/src/
  app/            ← composition root（router/access/theme/landing），保持薄
  auth/           ← session/http-client/refresh，纯领域逻辑
  data/           ← React Query/SWR 客户端 + zod schema（替换手写校验样板）
  design/         ← token-only theme（撤销 AdminLayout 内联样式）
  layout/         ← ProLayout 壳
  features/
    overview/     ← OverviewPage 拆为 <30 文件（dashboard / streams / cards）
    users/        ← UsersPage 拆分（list / detail / actions / hooks）
    mentor-audit/
    distribution-stats/
    knowledge-ops/
    palace-rag/
  shared/
    errors/       ← 唯一 toApiError + ApiError 类
    rbac/         ← 服务端权限解析；禁止前端硬编码权限码
    workbench/    ← 通用 shell 组件
  testing/        ← Vitest 配置 + 测试工具
```
**关键决策**：
- token 撤离 localStorage → **HttpOnly + SameSite=Strict cookie**，由 gateway 颁发与刷新；前端不再持久化 access token。
- 引入 **React Query**（或 SWR）替换 6 处手写轮询/流；缓存键统一在 `data/keys.ts`。
- 引入 **zod** 替换 `isRecord` / `readRequiredString` / `readEnumValue` 等 10 处样板。
- 引入 **ESLint + Prettier + Vitest**；e2e 已存在的 10 个 spec 保留，纳入 CI。
- RBAC 渲染由 `/me` 返回的服务端权限驱动，前端不再持权限码常量。

---

## 3. 设计系统规范（warmPaperAdmin → 三端统一）

### 3.1 Color Token（已确认）
| Token | Hex | 用途 |
|---|---|---|
| `accent` | `#FF8C42` | 主操作 / 强调 |
| `info` | `#3B8577` | 提示 / 信息 |
| `success` | `#6B8F5E` | 成功 / 完成 |
| `warning` | `#E6A817` | 警示 / 待办 |
| `error` | `#D94B3C` | 错误 / 危险 |
| `bgBase` | `#FFF8F0` | 背景底色 |

### 3.2 Radius / Spacing
- `radius.sm = 8` / `md = 16` / `lg = 24`
- spacing scale：`4 / 8 / 12 / 16 / 24 / 32 / 48`

### 3.3 Typography
- 中文：**PingFang SC**；英文/数字：**DM Sans**。
- type scale：`12 / 14 / 16 / 18 / 20 / 24 / 32`，行高 1.5（正文）/ 1.3（标题）。

### 3.4 Motion
- 默认 `duration.base = 200ms`，`easing = cubic-bezier(.2,.8,.2,1)`。
- **强制**：`prefers-reduced-motion: reduce` → 全部 transition / animation 降级为 `0ms`。
- mobile Auto-Flow 必须提供"暂停 / 关闭"控件，状态可持久化。

### 3.5 a11y
- 文本对比度 ≥ 4.5:1（正文）/ 3:1（大字号 / 图形）。
- 焦点环统一 token：`focus.outline = 2px solid accent, offset 2px`。
- mobile：所有交互组件具备 semanticsLabel；TalkBack/VoiceOver 录屏纳入回归。
- admin-web：键盘导航全覆盖；`aria-live` 用于轮询/流式区域。

### 3.6 文案
- 建立 `i18n/zh-CN.json` 单一文案源；术语表（mentor / practice / library / palace…）固定中文译名。
- 严禁 UI 内出现裸英文（除品牌/专有名词）。

---

## 4. 分期路线图（按端解耦，可并行）

> 端内顺序：**P0（阻塞 / 安全 / 门禁）→ P1（架构收口）→ P2（精致化与扩展）**
> 端间顺序：admin-web 先行（产出门禁与 token 体系样板）→ mobile → backend
> 但三端**互相不阻塞**，可由不同团队/agent 并行推进。

### 4.1 Phase 1 — Admin-Web（先行）

#### P0（安全 + 门禁，预计 6–9 人天）
- [ ] **撤离 localStorage token**：与 backend gateway 协同切 HttpOnly cookie；`session-store.ts:53-63` 仅保留 user profile 缓存。
- [ ] **统一 `toApiError`**：抽到 `shared/errors/`，删除三处重复（`auth-api.ts:164` / `MentorAuditPage.tsx:570` / `DistributionStatsPage.tsx:649`）。
- [ ] **引入 ESLint + Prettier + Vitest**：`pnpm add -D eslint prettier vitest @testing-library/react jsdom`；`scripts` 补齐 `lint` / `format` / `test` / `test:coverage`。
- [ ] **CI 门禁**：typecheck → lint → unit → e2e（已有 Playwright）→ build；任一失败阻塞合并。
- [ ] **覆盖率基线**：unit ≥ 40%（首期），关键 lib（auth / http-client / rbac）≥ 80%。

##### P0 验收标准（DoR / DoD）
- **DoR**：gateway 已确认 `Set-Cookie: HttpOnly; Secure; SameSite=Strict; Path=/admin-api` 字段；`/admin-api/auth/refresh` 契约冻结；CI runner 已具备 Node 20 + pnpm 9。
- **DoD（必须全部为真）**：
  1. `localStorage.getItem('babytalk.admin.session')` 在生产 build 中无任何调用点（`grep -R 'babytalk.admin.session' admin-web/src` 仅命中迁移注释）。
  2. `toApiError` 在仓库内仅存在 1 处定义（`admin-web/src/shared/errors/to-api-error.ts`），三处旧址改为 `import`。
  3. `pnpm lint` / `pnpm test` / `pnpm test:coverage` / `pnpm exec playwright test` 在 CI 全绿；coverage 报告产出到 `admin-web/coverage/lcov.info`。
  4. `.github/workflows/admin-web.yml` 含 5 个 job（typecheck / lint / unit / e2e / build），任一失败 PR 红灯。
  5. 关键 lib 行覆盖率 ≥ 80%：`auth/session-store.ts`、`auth/auth-api.ts`、`lib/api-client.ts`、`auth/access.ts`。

##### P0 契约骨架（HttpOnly Cookie + Refresh 单飞）
```ts
// admin-web/src/lib/api-client.ts（Before → After 骨架）
// Before: 读取 localStorage token 注入 Authorization 头
// After:  浏览器自动随 Cookie 发送；axios 仅负责 401 → refresh → 重放
export const apiClient = axios.create({
  baseURL: '/admin-api',
  withCredentials: true,            // ← 关键：携带 HttpOnly Cookie
  timeout: 15_000,
});

let refreshing: Promise<void> | null = null;
apiClient.interceptors.response.use(
  (r) => r,
  async (error: AxiosError) => {
    const original = error.config as InternalAxiosRequestConfig & { _retry?: boolean };
    if (error.response?.status !== 401 || original._retry) throw error;
    original._retry = true;
    refreshing ??= apiClient.post('/auth/refresh').finally(() => { refreshing = null; });
    await refreshing;               // ← 单飞：并发 401 共享同一次 refresh
    return apiClient(original);     // ← 重放原请求
  },
);
```

##### P0 错误归一骨架（`shared/errors/to-api-error.ts`）
```ts
// 唯一定义；删除 auth-api.ts:164 / MentorAuditPage.tsx:570 / DistributionStatsPage.tsx:649 三处副本
export interface ApiError { code: string; message: string; status: number; traceId?: string; }
export function toApiError(e: unknown): ApiError {
  if (axios.isAxiosError(e)) {
    const data = (e.response?.data ?? {}) as Partial<ApiError>;
    return {
      code: data.code ?? `HTTP_${e.response?.status ?? 0}`,
      message: data.message ?? e.message,
      status: e.response?.status ?? 0,
      traceId: data.traceId,
    };
  }
  return { code: 'UNKNOWN', message: String(e), status: 0 };
}
```

##### P0 CI 门禁骨架（`.github/workflows/admin-web.yml`）
```yaml
name: admin-web
on: { pull_request: { paths: ['admin-web/**'] } }
jobs:
  typecheck: { runs-on: ubuntu-latest, steps: [..., { run: pnpm -C admin-web typecheck }] }
  lint:      { runs-on: ubuntu-latest, steps: [..., { run: pnpm -C admin-web lint }] }
  unit:      { runs-on: ubuntu-latest, steps: [..., { run: pnpm -C admin-web test:coverage }] }
  e2e:       { runs-on: ubuntu-latest, steps: [..., { run: pnpm -C admin-web exec playwright test }] }
  build:     { runs-on: ubuntu-latest, steps: [..., { run: pnpm -C admin-web build }] }
```

##### P0 Checklist（合并前逐条勾选）
- [ ] gateway 颁发的 Cookie 在 Chrome/Edge/Safari/Firefox 四浏览器 DevTools → Application → Cookies 均显示 `HttpOnly ✓ Secure ✓ SameSite=Strict`。
- [ ] 退出登录调用 `POST /admin-api/auth/logout`，gateway 返回 `Set-Cookie: ...; Max-Age=0`，前端不再持有任何 token。
- [ ] 并发触发 5 个 401（DevTools throttling Slow 3G + 多 tab），仅观察到 1 次 `/auth/refresh` 网络请求。
- [ ] `pnpm lint` 零 error；`prettier --check` 零 diff。
- [ ] Vitest 报告显示 `auth/`、`lib/api-client.ts`、`auth/access.ts` 行覆盖率 ≥ 80%。
- [ ] PR 描述附 `coverage/lcov-report/index.html` 截图与 Playwright HTML 报告链接。
- [ ] CHANGELOG 增补「BREAKING: admin-web 不再读取 localStorage token；需配套部署 gateway ≥ vX.Y」。

#### P1（架构收口，预计 10–14 人天）
- [ ] **接入 React Query**：替换 `OverviewPage.tsx:16`、`IngestionSurface.tsx:27` 等手写轮询；统一 `INGESTION_POLL_INTERVAL_MS` / `MAX_INGESTION_POLL_ATTEMPTS` 到 `data/config.ts`。
- [ ] **接入 zod**：所有 client 输入输出 schema 化，删除 `isRecord` / `readRequiredString` / `readEnumValue` 重复。
- [ ] **RBAC 服务端化**：删除 `ADMIN_ROUTE_PERMISSION_CODES` 前端常量，从 `/me` 拉取；`access.ts` 仅做布尔 gate。
- [ ] **未登录 throw 修复**：`UsersPage.tsx:65-69` 改为 router guard + `<ForbiddenPage>` 跳转。
- [ ] **AdminLayout 去内联样式**：`adminSurfaceStyles.page` 迁入 token-only theme。

#### P2（精致化，预计 8–12 人天）
- [ ] **大页面拆分**：`PalaceRagSurface.tsx` / `UsersPage.tsx` / `OverviewPage.tsx` 按 features 子目录拆为 ≤300 行/文件。
- [ ] **Empty/Loading/Error 三态规范**：建立 `shared/states/` 统一组件。
- [ ] **a11y 通审**：键盘流、焦点环、对比度、`aria-live`；纳入 axe-core CI。
- [ ] **可视化精修**：图表 / 表格密度、空状态插画、微交互动效统一。

### 4.2 Phase 2 — Mobile（继 admin-web 后启动；可与 P1 并行）

#### P0（阻塞修复，预计 10–14 人天）

##### DoR（进入 P0 前必须满足）
1. `grep -rn 'ViewModel' lib/` 列出所有 ViewModel 文件（预计 5–10 处）。
2. 每处 ViewModel 对应的 Notifier 文件已存在或已规划。
3. CI 已有 `flutter analyze` + `dart format --set-exit-if-changed` job。
4. a11y 基线：`flutter test` 覆盖率报告已生成（当前值记录于此）。

##### DoD（P0 完成时必须达成）
1. **双真相源清零**：`grep -rn 'ViewModel' lib/ | grep -v test | grep -v '.g.dart'` 返回 0 结果。
2. **覆盖率基线**：`flutter test --coverage` 行覆盖率 ≥ 60%（P0 目标）；关键模块（`core/auth/`、`core/navigation/`、`features/mentor/`）≥ 80%。
3. **a11y 全绿**：axe-core 或 flutter_test a11y 扫描 0 critical；TalkBack/VoiceOver 手工冒烟通过。
4. **CI 全绿**：`flutter analyze` 0 error、`dart format --set-exit-if-changed` 0 diff、`flutter test` 0 fail、coverage 阈值通过。

##### P0 契约骨架（Riverpod 状态收口）

```dart
// lib/core/auth/auth_notifier.dart（Before → After 骨架）
// Before: AuthViewModel + AuthNotifier 双写；ViewModel 持有 _accessToken
// After:  AuthNotifier 唯一可写；ViewModel 删除；token 改 HttpOnly Cookie（与 §4.1 admin-web 同源）
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<AuthState> build() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    return session.fold(
      onLeft: (failure) => AuthState.unauthenticated(failure),
      onRight: (session) => AuthState.authenticated(session),
    );
  }

  /// 登录：gateway 颁发 HttpOnly Cookie；前端不再持有 token
  Future<void> login(String phone, String code) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).login(phone, code);
    state = result.fold(
      onLeft: (failure) => AsyncError(failure, StackTrace.current),
      onRight: (_) => AsyncData(AuthState.authenticated(_)),
    );
  }

  /// 登出：调用 gateway revoke；清空本地状态
  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState.unauthenticated(null));
  }
}

// derived selector（取代原 ViewModel 的 _isAuthenticated / _user 等字段）
@riverpod
bool isAuthenticated(IsAuthenticatedRef ref) =>
    ref.watch(authNotifierProvider).valueOrNull?.isAuthenticated ?? false;

@riverpod
AppUser? currentUser(CurrentUserRef ref) =>
    ref.watch(authNotifierProvider).valueOrNull?.user;
```

##### P0 BootCoordinator 拆分骨架

```dart
// lib/core/bootstrap/boot_coordinator.dart（Before → After 骨架）
// Before: 单一 BootCoordinator 职责过重（auth + session + feature gates 混杂）
// After:  三独立组件，各司其职
class AuthStateBootstrapper {
  /// 恢复认证状态（从 HttpOnly Cookie 自动携带）
  Future<AuthState> restore() async { ... }
}

class SessionBootstrapper {
  /// 恢复用户会话（profile、preferences、本地缓存）
  Future<SessionState> restore(String userId) async { ... }
}

class FeatureGatesBootstrapper {
  /// 恢复 feature flags（远程配置 + 本地缓存）
  Future<FeatureGates> restore() async { ... }
}

// 组合入口（composition root）
class BootCoordinator {
  final AuthStateBootstrapper _auth;
  final SessionBootstrapper _session;
  final FeatureGatesBootstrapper _gates;

  Future<BootstrapResult> boot() async {
    final auth = await _auth.restore();
    if (!auth.isAuthenticated) return BootstrapResult.unauthenticated();
    final session = await _session.restore(auth.userId);
    final gates = await _gates.restore();
    return BootstrapResult.ready(auth, session, gates);
  }
}
```

##### P0 a11y 契约骨架

```dart
// lib/shared/a11y/a11y_utils.dart（新增）
/// 检查系统是否开启 reduce-motion
bool shouldReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.boldTextOf(context);

/// 包装动画组件：reduce-motion 时跳过动画
Widget conditionalAnimation({
  required Widget child,
  required Widget Function(Widget child) withAnimation,
}) {
  return Builder(
    builder: (context) => shouldReduceMotion(context)
        ? child
        : withAnimation(child),
  );
}
```

##### P0 CI 门禁骨架（`.github/workflows/mobile.yml`）

```yaml
name: mobile
on: { pull_request: { paths: ['mobile/**'] } }
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter analyze
      - run: dart format --set-exit-if-changed .
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v4
        with:
          files: coverage/lcov.info
          fail_ci_if_error: true
          thresholds: '60'
  a11y:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter test test/a11y/  # axe-core 或自定义 a11y 测试
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter build apk --debug
```

##### P0 Checklist（合并前逐条勾选）

- [ ] `grep -rn 'ViewModel' lib/ | grep -v test | grep -v '.g.dart'` 返回 0 结果。
- [ ] `flutter test --coverage` 显示总体 ≥ 60%，`core/auth/`、`core/navigation/`、`features/mentor/` 各 ≥ 80%。
- [ ] `flutter analyze` 0 error；`dart format --set-exit-if-changed` 0 diff。
- [ ] TalkBack（Android）+ VoiceOver（iOS）手工冒烟：登录 → 首页 → 练习 → 退出，所有可交互元素可聚焦、可朗读。
- [ ] Auto-Flow 暂停按钮存在且可操作；`prefers-reduced-motion` 开启时动画跳过。
- [ ] CI workflow 4 job（analyze / test / a11y / build）全绿；coverage 阈值 60% 硬阻塞。
- [ ] PR 描述包含：双真相源消除前后文件对照表、覆盖率报告截图、a11y 扫描截图。

#### P1（架构收口，预计 12–18 人天）
- [ ] **app/ 收口为纯 composition root**（7–10 人天）。
- [ ] **bounded context contract**（8–12 人天）：features 之间仅通过 contract 通信；禁跨 feature import。
- [ ] **路由 + 深链 + 重入流**抽取到 `core/navigation/`，受单测覆盖。
- [ ] **theme/token 统一**：建 `design/tokens.dart`；删除硬编码颜色/尺寸。

#### P2（精致化，预计 10–14 人天）
- [ ] **核心路径去稀释**：Mentor FAB 与 C3 信息架构合并；4-tab 边界明确化。
- [ ] **练习页首屏减载**：分段披露 + skeleton。
- [ ] **文案统一**：术语表 + i18n 中文化。
- [ ] **TalkBack/VoiceOver 回归**：纳入手工 + 自动化（Patrol/Maestro）冒烟。

### 4.3 Phase 3 — Backend（与前两端并行；安全/门禁优先）

#### P0（安全 + 合规，预计 10–14 人天）

##### DoR（进入 P0 前必须满足）
1. `docs/rbac.md` 模板已存在（角色 × 资源 × 操作矩阵骨架）。
2. `docs/token-lifecycle.md` 模板已存在（access / refresh / rotate / revoke 流程骨架）。
3. `docs/privacy/children-voice.md` 模板已存在（分级标准 + 加密 + 审计 + 留存骨架）。
4. gateway 限流配置模板已存在（IP / user / endpoint 三维骨架）。

##### DoD（P0 完成时必须达成）
1. **token 生命周期文档化**：`docs/token-lifecycle.md` 包含 access (15min) + refresh (7d, HttpOnly Cookie) + rotate 策略 + revoke 链路；e2e 覆盖 refresh + revoke。
2. **RBAC 矩阵 100% 覆盖**：`docs/rbac.md` 包含 admin-api 全部角色 × 资源 × 操作；`@PreAuthorize` 注解 100% 覆盖；审计落点（who/what/when/where）100%。
3. **儿童语音隐私合规**：`docs/privacy/children-voice.md` 包含分级标准（Level 1-3）+ AES-256 加密 + 访问审计 + 留存策略（≤30d）；法务 review 通过。
4. **gateway 限流上线**：IP 维度 100 req/min、user 维度 50 req/min、endpoint 维度 10 req/s；异常响应 `{"code":"RATE_LIMITED","message":"...","retryAfter":60}`。
5. **CI 全绿**：`mvn checkstyle` 0 error、`mvn test` ≥ 70% 覆盖率、dependency-check 0 high/critical。

##### P0 Token 生命周期契约骨架

```java
// gateway/src/main/java/.../auth/TokenService.java（Before → After 骨架）
// Before: access + refresh 均在前端 localStorage；gateway 不感知 token 状态
// After:  access (15min, 内存) + refresh (7d, HttpOnly Cookie)；gateway 颁发 + 轮换 + 撤销
@Service
public class TokenService {
    private final JwtEncoder encoder;
    private final RefreshTokenRepository refreshRepo;

    /// 颁发 token 对：access (内存) + refresh (HttpOnly Cookie)
    public TokenPair issue(String userId, String roles) {
        String access = encoder.encode(JwtClaimsSet.builder()
            .subject(userId)
            .claim("roles", roles)
            .issuedAt(Instant.now())
            .expiresAt(Instant.now().plus(Duration.ofMinutes(15)))
            .build());
        RefreshToken refresh = refreshRepo.save(new RefreshToken(userId, Duration.ofDays(7)));
        return new TokenPair(access, refresh.token());
    }

    /// 轮换：旧 refresh 失效 + 颁发新 token 对
    public TokenPair rotate(String oldRefreshToken) {
        RefreshToken old = refreshRepo.findByToken(oldRefreshToken)
            .orElseThrow(() -> new InvalidTokenException("refresh_not_found"));
        old.revoke();
        return issue(old.userId(), old.roles());
    }

    /// 撤销：登出时清空 refresh
    public void revoke(String userId) {
        refreshRepo.revokeAllByUserId(userId);
    }
}

// gateway Cookie 配置（application.yml）
// server.servlet.session.cookie:
//   http-only: true
//   secure: true
//   same-site: strict
//   max-age: 604800  # 7d
```

##### P0 RBAC 矩阵契约骨架

```markdown
# docs/rbac.md（骨架）

## 角色定义
| 角色 | code | 说明 |
|------|------|------|
| 超级管理员 | SUPER_ADMIN | 全部权限 |
| 运营管理员 | OPERATOR | 用户管理 + 内容审核 |
| 数据分析师 | ANALYST | 只读统计 |
| 家长 | PARENT | 仅查看自己孩子数据 |

## 资源 × 操作矩阵
| 资源 | CREATE | READ | UPDATE | DELETE | 审计 |
|------|--------|------|--------|--------|------|
| /admin-api/users | OPERATOR+ | ANALYST+ | OPERATOR+ | SUPER_ADMIN | ✓ |
| /admin-api/mentor-audit | — | OPERATOR+ | OPERATOR+ | — | ✓ |
| /admin-api/distribution | — | ANALYST+ | — | — | ✓ |
| /admin-api/knowledge | OPERATOR+ | ANALYST+ | OPERATOR+ | SUPER_ADMIN | ✓ |
| /app-api/children/{id}/voice | PARENT+ | PARENT+ | — | — | ✓ |

## 审计落点
- `@Audited` 注解标记所有写操作
- `AuditLog` 表：who / what / when / where / ip / userAgent
- 保留策略：90d 热存储 + 180d 冷存储
```

##### P0 儿童语音隐私契约骨架

```markdown
# docs/privacy/children-voice.md（骨架）

## 分级标准
| 级别 | 定义 | 加密 | 审计 | 留存 |
|------|------|------|------|------|
| Level 1 | 语音指令（无 PII） | AES-256-GCM | 访问日志 | 30d |
| Level 2 | 语音对话（含姓名） | AES-256-GCM + KMS | 访问日志 + 告警 | 14d |
| Level 3 | 语音对话（含敏感信息） | AES-256-GCM + KMS + 硬件安全模块 | 访问日志 + 告警 + 审批 | 7d |

## 加密实现
```java
// common/src/main/java/.../crypto/VoiceEncryptor.java
@Component
public class VoiceEncryptor {
    private final KmsClient kms;
    private final SecureRandom random = new SecureRandom();

    public EncryptedVoice encrypt(byte[] audio, VoiceLevel level) {
        byte[] key = level.requiresKms() ? kms.generateDataKey() : generateLocalKey();
        byte[] iv = new byte[12];
        random.nextBytes(iv);
        byte[] ciphertext = aesGcmEncrypt(audio, key, iv);
        return new EncryptedVoice(ciphertext, iv, key.getId(), level);
    }

    public byte[] decrypt(EncryptedVoice encrypted) {
        byte[] key = resolveKey(encrypted.keyId());
        return aesGcmDecrypt(encrypted.ciphertext(), key, encrypted.iv());
    }
}
```

## 审计接口
```java
// common/src/main/java/.../audit/VoiceAuditService.java
public interface VoiceAuditService {
    void logAccess(String userId, String childId, VoiceLevel level, String purpose);
    void logExport(String userId, String childId, VoiceLevel level, int count);
    void alertAnomaly(String userId, String childId, String pattern);
}
```
```

##### P0 Gateway 限流契约骨架

```java
// gateway/src/main/java/.../ratelimit/RateLimitFilter.java（Before → After 骨架）
// Before: 无限流；异常响应不规范
// After:  三维限流（IP / user / endpoint）；异常响应统一格式
@Component
public class RateLimitFilter extends OncePerRequestFilter {
    private final RateLimiter ipLimiter;      // 100 req/min
    private final RateLimiter userLimiter;    // 50 req/min
    private final RateLimiter endpointLimiter; // 10 req/s

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String ip = req.getRemoteAddr();
        String user = extractUserId(req);
        String endpoint = req.getRequestURI();

        if (!ipLimiter.tryAcquire(ip)) {
            writeRateLimitResponse(res, "IP_RATE_LIMITED", 60);
            return;
        }
        if (user != null && !userLimiter.tryAcquire(user)) {
            writeRateLimitResponse(res, "USER_RATE_LIMITED", 60);
            return;
        }
        if (!endpointLimiter.tryAcquire(endpoint)) {
            writeRateLimitResponse(res, "ENDPOINT_RATE_LIMITED", 10);
            return;
        }
        chain.doFilter(req, res);
    }

    private void writeRateLimitResponse(HttpServletResponse res, String code, int retryAfter)
            throws IOException {
        res.setStatus(429);
        res.setContentType("application/json");
        res.getWriter().write("""
            {"code":"%s","message":"Too many requests","retryAfter":%d}
            """.formatted(code, retryAfter));
    }
}
```

##### P0 CI 门禁骨架（`.github/workflows/backend.yml`）

```yaml
name: backend
on: { pull_request: { paths: ['backend/**'] } }
jobs:
  checkstyle:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
      - run: mvn -pl admin-api,app-api,common,gateway checkstyle:check
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
      - run: mvn test
      - uses: codecov/codecov-action@v4
        with:
          files: '**/target/site/jacoco/jacoco.xml'
          fail_ci_if_error: true
          thresholds: '70'
  dependency-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
      - run: mvn org.owasp:dependency-check-maven:check
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: '**/dependency-check-report.sarif'
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
      - run: mvn package -DskipTests
```

##### P0 Checklist（合并前逐条勾选）

- [ ] `docs/token-lifecycle.md` 存在且包含 access/refresh/rotate/revoke 全链路；e2e 覆盖 refresh + revoke。
- [ ] `docs/rbac.md` 存在且包含 admin-api 全部角色 × 资源 × 操作矩阵；`@PreAuthorize` 覆盖率 100%。
- [ ] `docs/privacy/children-voice.md` 存在且包含分级标准 + 加密实现 + 审计接口 + 留存策略；法务 review 通过。
- [ ] gateway 限流配置生效：IP 100 req/min、user 50 req/min、endpoint 10 req/s；异常响应格式统一。
- [ ] `mvn checkstyle:check` 0 error；`mvn test` 行覆盖率 ≥ 70%；dependency-check 0 high/critical。
- [ ] PR 描述包含：RBAC 矩阵截图、token 生命周期流程图、限流压测报告、dependency-check 报告截图。

#### P1（架构收口，预计 12–16 人天）
- [ ] **BootCoordinator 拆分**：`auth-state` / `session-bootstrap` / `feature-gates` 三独立组件。
- [ ] **dispatch contract 落地**：启动恢复 / 首页 / Practice 三处 contract 文档 + 单测。
- [ ] **一致性模型**：明确强一致 vs 最终一致边界；写明 saga / outbox 使用范围。
- [ ] **外部 API 授权矩阵**：第三方 token 持有者 / 范围 / 失败降级写文档。

#### P2（性能 + 可观测，预计 8–12 人天）
- [ ] **10× 容量演练**：热点链路压测 + 索引审查（db-migration 评审清单纳入）。
- [ ] **查询 → 数据模型 / 索引 / 缓存** 优化矩阵。
- [ ] **可观测**：actuator + metrics + tracing 全覆盖；关键链路 SLI/SLO 文档。

---

## 5. 风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| Token 存储切换破坏现有会话 | 高 | 灰度 + 双轨期（cookie + localStorage 共存 1 周）+ 强制重新登录通告 |
| 双真相源拆解引入回归 | 高 | 拆解前补 Notifier 单测 + golden test；按 feature 分批 |
| 大页面拆分破坏 e2e | 中 | 拆分前/后对照运行 10 个 spec；保留 selector 稳定性 |
| RBAC 服务端化导致权限闪烁 | 中 | 首屏 `/me` 完成前用 skeleton；缓存上次会话权限做 SWR fallback |
| 儿童语音合规改造延期 | 高 | P0 必交付；与法务/合规 review 并行；交付前不上量 |
| Flyway 迁移在 10× 容量下卡住 | 中 | 评审清单 + 影子库演练；高风险迁移走在线 DDL |
| Maven 模块边界腐化复发 | 中 | ArchUnit 规则入 CI；禁止 common → service 反向依赖 |
| Flutter 包体积膨胀 | 低 | size-budget CI；动效与图片资源审查 |

---

## 6. 发布门禁矩阵

| 层级 | Mobile | Backend | Admin-Web |
|---|---|---|---|
| Lint | `flutter analyze` | `mvn checkstyle` + `spotbugs` | `eslint` |
| Format | `dart format --set-exit-if-changed` | `spotless:check` | `prettier --check` |
| Typecheck | （dart 自带） | （javac 自带） | `tsc -p tsconfig.json && tsc -p tsconfig.node.json` |
| Unit | `flutter test --coverage` ≥ 60% | `mvn test` ≥ 70% | `vitest run --coverage` ≥ 40%（首期） |
| Integration | quick integration pack | `@SpringBootTest` 关键链路 | （并入 e2e） |
| E2E | Patrol/Maestro 冒烟 | contract test（pact） | Playwright 10 spec（已有） |
| Security | dependency scan | dependency-check + RBAC 矩阵 review | `npm audit` + axe-core |
| Release | 版本号 + changelog + 灰度 | helm upgrade（已配置 babytalk / babytalk-qa）| build → preview → 灰度 |

**强制规则**：任一层失败 → 阻塞合并 / 阻塞发布。CI 不允许 `--no-verify`、不允许跳过覆盖率检查。

---

## 7. 团队与节奏建议

- **三端并行**：admin-web / mobile / backend 各一名 owner；共享 design system owner 1 名。
- **节奏**：双周迭代；每端每迭代必须交付 1 个 P0 或 2 个 P1。
- **评审**：P0 完成后须由 oracle / 安全 review 双签；P1 完成后须有 e2e 通过证据。
- **沟通**：跨端契约（token、RBAC、dispatch contract）通过 `docs/contracts/` 单一文档源同步。

---

## 8. 验收标准（Definition of Done）

### 8.1 Admin-Web
- [ ] localStorage 不再持有 access token；`SESSION_STORAGE_KEY` 仅缓存非敏感 profile
- [ ] `toApiError` 全局唯一
- [ ] `lint` / `format` / `test` / `test:e2e` 全绿；coverage ≥ 40%
- [ ] 6 大页面无单文件 > 500 行
- [ ] axe-core CI 0 critical
- [ ] 前端不再持有任何权限码常量

### 8.2 Mobile
- [ ] 双真相源清零（grep 验证）
- [ ] WCAG 2.1 AA 通过率 100%（关键路径）
- [ ] Auto-Flow 暂停 + reduced-motion 验证通过
- [ ] flutter test coverage ≥ 60%
- [ ] features/ 之间无跨 feature import（lint 规则强制）

### 8.3 Backend
- [ ] RBAC 矩阵文档存在且与代码一致（CI 校验）
- [ ] token 生命周期文档存在；refresh / revoke 链路 e2e 覆盖
- [ ] 儿童语音数据分级 + 加密 + 审计 100%
- [ ] gateway 限流策略上线；压测达 10× 容量
- [ ] 关键链路 SLI/SLO 文档存在

---

## 9. 附录

### 9.1 证据来源
- `.ao-output/UX审查-2026-05-11/summary.md`
- `.ao-output/技术债务-2026-05-11/summary.md`
- `.ao-output/技术方案-2026-05-11/summary.md`
- `.gstack/main-autoplan-restore-20260406-092516.md`
- `~/.gstack/projects/zhangspaghetti-baby-talk-2/gsd-autoplan-restore-20260426-102327.md`
- `.gsd/milestones/M006/slices/S05/`
- 9 路 explore agent 产物（A1–A6 文档审 + B1 mobile / B2 backend / B3 admin-web 源码抽样）
- 主对话直读：admin-web app / auth / layout / workbench / lib / pages / config 全量小文件

### 9.2 关键文件锚点（admin-web）
- 路由：`src/app/routes.tsx`
- 权限：`src/app/access.ts`
- Theme：`src/app/theme.ts`
- Auth：`src/auth/{auth-api,auth-provider,http-client,session-store}.ts`
- Layout：`src/layout/AdminLayout.tsx`
- Workbench：`src/components/workbench/*`
- Clients：`src/lib/{authClient,adminAccountsClient,usersClient,overviewClient,mentorAuditClient,distributionStatsClient,knowledgeOpsClient,knowledgeOpsUtils}.ts`
- E2E：`tests/*.spec.ts` 10 个

### 9.3 部署上下文（已配置）
- 生产 namespace：`babytalk`（gateway 8090 / admin-web 3000）
- QA namespace：`babytalk-qa`（gateway 8091 / admin-web 3001，PVC 持久化）
- 部署：`helm upgrade --install babytalk-app deploy/helm/babytalk-app …`

---

**Sign-off 待办**：本文档作为战略蓝图，需经用户确认后进入实施阶段。实施期间每完成一个 P0/P1 子项，更新本文档 §4 对应 checkbox，并在 PR 描述中引用本文件锚点。
