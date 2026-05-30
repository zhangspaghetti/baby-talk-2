# BabyTalk 安全与合规策略文档

> 最后更新: 2026-05-28  
> 适用范围: BabyTalk Flutter 移动端 + Spring Boot 后端  
> 目标受众: 安全审计、隐私合规评审、架构决策

---

## 目录

1. [COPPA 合规](#1-coppa-合规)
2. [数据加密策略](#2-数据加密策略)
3. [API 安全](#3-api-安全)
4. [安全存储](#4-安全存储)
5. [隐私政策要求](#5-隐私政策要求)
6. [数据生命周期管理](#6-数据生命周期管理)
7. [威胁模型](#7-威胁模型)
8. [审计与监控](#8-审计与监控)

---

## 1. COPPA 合规

### 1.1 什么是 COPPA

COPPA (Children's Online Privacy Protection Act) 要求面向 13 岁以下儿童的在线服务必须获得家长的可验证同意 (VPC) 才能收集、使用或披露儿童个人信息。BabyTalk 的目标用户为 **0-3 岁婴幼儿的中国家长**，属于 COPPA 的严格适用范围。

### 1.2 数据收集清单

| 数据类别 | 具体字段 | 是否涉及儿童数据 | 收集目的 |
|---------|---------|----------------|---------|
| **账户认证** | 手机号 (脱敏)、sessionId | 否 — 收集的是家长手机号 | 身份验证 |
| **婴幼儿信息** | 宝宝月龄/年龄、宝宝昵称 | **是** — 直接描述儿童 | 内容个性化匹配 |
| **练习记录** | activityId、phraseId、reactionType、时间戳 | 间接 — 记录的是儿童行为数据 | 学习进度追踪 |
| **Mentor 交互** | redactedSummary、visibleStatus、phase | 间接 — 基于儿童练习生成 | 个性化建议 |
| **设备标识** | installationId (UUID) | 否 — 设备级匿名 ID | 设备绑定、会话管理 |

### 1.3 家长同意机制

```dart
// 已实现: AccountConsentState 定义了完整的同意生命周期
enum AccountConsentState {
  localOnly,          // 未同意 — 数据仅在设备本地
  signedOut,          // 已退出 — 同意已撤回
  acceptedPendingSync, // 已同意 — 等待首次同步
  revoked,            // 同意已撤回
  deleted,            // 账户已删除
}
```

**同意流程设计:**

1. **首次使用 (localOnly)**: 用户可完全离线使用，不收集任何数据到服务器
2. **手机号验证 (acceptedPendingSync)**: 用户输入手机号获取验证码，此时视为家长主动同意数据收集
3. **同意撤回 (revoked)**: 用户可在设置中撤回同意，触发服务端数据删除 + 本地数据清除
4. **账户删除 (deleted)**: 触发完整的数据擦除流程

**COPPA 合规增强建议:**

- 在手机号验证前增加明确的 **"家长同意弹窗"**，单独列出将收集的儿童相关数据
- 同意弹窗应使用家长能理解的语言（非技术术语）
- 记录同意时间戳和同意版本号，用于合规审计
- 提供**每年一次**的同意重新确认机制（COPPA 要求年度 re-consent）

### 1.4 数据最小化原则

| 原则 | 当前实现 | 改进建议 |
|-----|---------|---------|
| 仅收集必要数据 | 手机号验证而非完整注册 | 已符合 — 无需姓名/邮箱 |
| 匿名化 | installationId 为 UUID | 已符合 — 无设备指纹 |
| 最小化儿童数据 | 仅收集月龄/年龄 | 已符合 — 不收集姓名/照片/位置 |
| 本地优先 | localOnly 模式 | 已符合 — 数据默认不上传 |
| 自动清理 | sensitive data clearance | 已符合 — 支持按触发器清理 |

### 1.5 年龄验证

BabyTalk 不直接对儿童进行年龄验证（儿童是间接用户）。年龄信息由家长主动提供，用于内容匹配。

**建议实现:**
- 收集宝宝月龄时提供滑动选择器而非自由输入（减少误填）
- 对极端值进行合理性校验（如 0-48 个月）
- 不使用自动化工具验证儿童年龄（这在 COPPA 中被视为儿童数据收集）

---

## 2. 数据加密策略

### 2.1 数据静态加密 (Data at Rest)

#### Isar 本地数据库

| 存储内容 | 加密状态 | 实现方案 |
|---------|---------|---------|
| InteractionEventEntity | **未加密** — Isar 默认无加密 | 建议启用 Isar 编译时加密或文件级加密 |
| MentorFactEventEntity | **未加密** — 同上 | 同上 |
| OnboardingSnapshot | **未加密** — 同上 | 同上 |
| GardenGrowthSnapshot | **未加密** — 同上 | 同上 |

**风险评估:** Isar 数据库文件存储在应用沙箱目录，iOS 上有 Keychain 保护，Android 上有应用沙箱隔离。但 root/越狱设备上数据库文件可能被直接读取。

**建议:**
- 对包含敏感数据的 Isar collection 启用字段级加密
- 或在写入前对敏感字段进行 AES-256-GCM 加密
- 考虑使用 `flutter_secure_storage` 存储 Isar 的加密密钥

#### flutter_secure_storage 存储

| 存储 Key | 内容 | 加密状态 |
|----------|-----|---------|
| `account_state` | AccountLocalSnapshot (session + consent) | **已加密** — iOS Keychain / Android Keystore |

已实现的 `AccountLocalStore` 使用 `flutter_secure_storage` 存储完整会话状态，包括 JWT tokens，底层依赖 iOS Keychain / Android Keystore，提供了硬件级加密保护。

### 2.2 数据传输加密 (Data in Transit)

| 传输通道 | 加密状态 | 实现方案 |
|---------|---------|---------|
| Mobile -> Gateway (API) | **HTTPS** | Dio + TLS 1.2+ |
| Gateway -> App-API | **内部网络** | Kubernetes 集群内通信 |
| App-API -> LLM | **HTTPS** | 外部 API 调用 |
| Admin-Web -> Gateway | **HTTPS** | 反向代理 TLS 终止 |

**证书固定 (Certificate Pinning):**

当前未实现证书固定。在生产环境中建议:
- iOS: 使用 `url_launcher` 或自定义 `SecurityContext` 实现 pinning
- Android: 使用 Network Security Config XML
- 至少 pin 住 CA 证书（而非叶证书），降低证书轮换风险

### 2.3 密钥管理

| 密钥类型 | 存储位置 | 轮换策略 |
|---------|---------|---------|
| JWT 签名密钥 | 后端 Spring Boot `application.yml` | 建议 90 天轮换 |
| Isar 加密密钥 | 待实现 — 建议存入 Keychain/Keystore | 跟随应用版本更新 |
| API 密钥 (LLM) | 后端环境变量 | 建议 180 天轮换 |
| TLS 证书 | Kubernetes Ingress | 自动轮换 (cert-manager) |

---

## 3. API 安全

### 3.1 认证 (Authentication)

**当前实现:**

```dart
// Bearer Token 认证
// mobile/lib/core/network/auth_headers.dart
String? buildBearerAuthorizationHeaderValue(String? accessToken) {
  final normalized = accessToken?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return 'Bearer $normalized';
}
```

```java
// 后端: JWT Bearer Token
// mobile/lib/features/account/domain/models/account_session.dart
// session 包含: accessToken, refreshToken, tokenType, expiresAt
```

**认证流程:**

1. 家长输入手机号 -> 后端发送 SMS 验证码
2. 验证码校验通过 -> 返回 JWT (accessToken + refreshToken)
3. accessToken 过期 -> 使用 refreshToken 自动刷新
4. refreshToken 过期 -> 引导用户重新登录

**JWT Token 安全要求:**

| 属性 | 建议值 | 说明 |
|-----|-------|-----|
| accessToken TTL | 15-30 分钟 | 短生命周期降低泄露风险 |
| refreshToken TTL | 7-30 天 | 平衡安全与用户体验 |
| 签名算法 | RS256 或 ES256 | 非对称签名，防止伪造 |
| Issuer | `babytalk.example.com` | 明确签发方 |
| Audience | `babytalk-app` | 明确受众 |

### 3.2 授权 (Authorization)

**用户作用域隔离:**

```java
// 后端: 所有 API 调用都通过 Bearer Token 绑定到特定用户
// 确保用户只能访问自己的数据
// 已实现: 用户级作用域 (accountId)
```

| API 模块 | 作用域规则 | 实现状态 |
|---------|----------|---------|
| Account API | 仅限自身账户 | 已实现 |
| Practice API | 仅限自身练习记录 | 已实现 |
| Mentor API | 仅限自身 mentor 交互 | 已实现 |
| Household API | 仅限家庭成员 | 已实现 |
| Share API | 分享链接需 token 验证 | 已实现 |
| Admin API | 仅限管理员角色 | 已实现 |

**角色分级:**
- `parent` — 普通家长用户
- `admin` — 管理后台操作员
- `staff_plus` — 高权限操作（数据删除审批）

### 3.3 速率限制

**已实现:**

```java
// 后端: RateLimiterConfig + GatewayRateLimitErrorHandler
// 后端: MentorRateLimitConcurrencyTest — 并发限流测试
```

**速率限制策略:**

| 端点类别 | 限制 | 说明 |
|---------|-----|-----|
| 登录/验证码 | 5 次/分钟/IP | 防止暴力破解 |
| Token 刷新 | 10 次/分钟/用户 | 防止 token 轮换攻击 |
| Mentor LLM 调用 | 按 MentorProperties 配置 | 防止 LLM 滥用 |
| 普通 API | 60 次/分钟/用户 | 基本 DDoS 防护 |
| 文件上传 | 10 次/分钟/用户 | 防止存储滥用 |

### 3.4 输入验证

**后端验证:**
- Spring Boot + Validation 注解
- 所有 API 入参必须经过 `@Valid` 校验
- 电话号码格式校验 (中国手机号正则)
- 月龄/年龄范围校验 (0-48 个月)
- 字符串长度限制防止注入

**前端验证:**
- `AccountSession.validated()` 工厂方法强制校验
- `AccountLocalSnapshot` 构造函数中的格式校验
- 所有 Isar Entity 写入前经过 `toPersistedFactMap()` 格式化

---

## 4. 安全存储

### 4.1 Token 存储

```dart
// AccountLocalStore — 使用 flutter_secure_storage
class AccountLocalStore {
  final FlutterSecureStorage _secureStorage;
  final String storageKey = 'account_state';

  // iOS: 存入 Keychain (硬件加密)
  // Android: 存入 Android Keystore (硬件加密)
  // 不使用 SharedPreferences /明文文件
}
```

**存储安全矩阵:**

| 数据 | 存储位置 | 加密方式 | 可备份 | 可导出 |
|-----|---------|---------|-------|-------|
| JWT Tokens | flutter_secure_storage | Keychain/Keystore | 受限 | 否 |
| 手机号 (脱敏) | flutter_secure_storage | Keychain/Keystore | 受限 | 否 |
| 会话状态 | flutter_secure_storage | Keychain/Keystore | 受限 | 否 |
| 练习记录 | Isar DB | 应用沙箱 | 可备份 | 用户可导出 |
| Mentor 事件 | Isar DB | 应用沙箱 | 可备份 | 用户可导出 |
| Onboarding 数据 | Isar DB | 应用沙箱 | 可备份 | 用户可导出 |

### 4.2 敏感数据分级

| 级别 | 定义 | 数据示例 | 保护措施 |
|-----|-----|---------|---------|
| **L1 - 极敏感** | 可直接关联个人身份 | 手机号 (原始) | 不存储 — 仅在验证时短暂持有 |
| **L2 - 敏感** | 可关联账户 | JWT Token、脱敏手机号 | flutter_secure_storage |
| **L3 - 个人数据** | 儿童相关数据 | 宝宝月龄、昵称、练习记录 | Isar + 应用沙箱 |
| **L4 - 匿名数据** | 不可关联个人 | installationId、设备型号 | 无特殊保护 |

### 4.3 数据保留策略

| 数据类型 | 保留期限 | 删除触发条件 |
|---------|---------|------------|
| JWT accessToken | 15-30 分钟 | 自动过期 |
| JWT refreshToken | 7-30 天 | 自动过期 |
| 练习记录 | 账户存续期间 | 账户删除 |
| Mentor 交互记录 | 账户存续期间 | 账户删除 |
| Onboarding 数据 | 账户存续期间 | 账户删除 |
| 服务端聚合数据 | 匿名保留 | 无法追溯个人 |

---

## 5. 隐私政策要求

### 5.1 必须披露的信息

根据 COPPA 和中国《个人信息保护法》(PIPL)，隐私政策必须包含:

#### 收集的数据

| 数据项 | 收集目的 | 法律依据 |
|-------|---------|---------|
| 手机号 (脱敏) | 身份验证 | 合同履行 |
| 宝宝月龄 | 内容个性化 | 同意 |
| 宝宝昵称 | 个性化称呼 | 同意 |
| 练习记录 | 学习进度追踪 | 同意 |
| Mentor 交互 | 个性化建议 | 同意 |
| installationId | 设备管理 | 合法利益 |

#### 数据使用方式

- **不会**用于广告定向
- **不会**出售给第三方
- **不会**用于除服务提供以外的其他目的
- Mentor 建议生成时会将练习数据发送给 LLM 服务商，已做脱敏处理

#### 数据共享

| 共享方 | 共享数据 | 目的 | 保护措施 |
|-------|---------|-----|---------|
| LLM 服务提供商 | 脱敏后的练习摘要 | Mentor 建议生成 | 数据处理协议 |
| 云服务商 | 所有服务端数据 | 基础设施托管 | 数据处理协议 |

#### 用户权利

| 权利 | 实现方式 |
|-----|---------|
| **访问权** | 用户可在 App 中查看所有个人数据 |
| **删除权** | 设置 -> 账户删除，触发完整数据擦除 |
| **撤回同意** | 设置 -> 撤回同意，停止数据同步 |
| **数据可携带** | 未来可实现导出功能 |
| **限制处理** | 撤回同意后限制为仅本地处理 |

### 5.2 儿童隐私专节

COPPA 要求在隐私政策中单独设立"儿童隐私"章节:

- 明确说明收集的儿童数据类型（月龄、昵称、练习记录）
- 说明家长有权拒绝数据收集并继续使用离线功能
- 提供家长联系方式用于隐私相关咨询
- 说明数据保留和删除政策

---

## 6. 数据生命周期管理

### 6.1 已实现的敏感数据清除机制

```dart
// 完整的本地数据清除编排器
// mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart
```

**清除触发器:**

| 触发器 | 清除范围 | 需要审批 |
|-------|---------|---------|
| `logoutSessionOnly` | 仅 accountLocalSnapshot | 否 |
| `consentWithdrawalConfirmed` | account + household + mentor | 否 |
| `accountDeletionConfirmed` | **全部数据** | 是 (staffPlus) |
| `deviceEraseConfirmed` | **全部数据** | 是 (staffPlus) |
| `staffPlusVerificationOnly` | **全部数据** | 是 (staffPlus) |

**清除目标:**

| 清除目标 | 说明 |
|---------|-----|
| `accountLocalSnapshot` | 账户会话、JWT Token |
| `onboardingSnapshot` | 宝宝信息、个性化设置 |
| `householdSnapshot` | 家庭信息 |
| `practiceInteractionEvents` | 所有练习记录 |
| `mentorFactEvents` | 所有 Mentor 交互 |
| `installationId` | 设备标识 |

### 6.2 清除报告审计

每次清除操作都生成结构化报告:

```dart
LocalSensitiveDataClearanceReport(
  correlationId: '...',      // 唯一追踪 ID
  trigger: '...',            // 触发器类型
  requestedAt: DateTime,     // 请求时间
  startedAt: DateTime,       // 开始时间
  finishedAt: DateTime,      // 完成时间
  overallStatus: 'completed' | 'completedWithFailures' | 'rejectedByGovernance',
  authorizationEvidence: LocalSensitiveDataAuthorizationEvidence(
    kind: 'staff_plus_destructive',
    decisionId: '...',
    approvedBy: '...',
    approvedAt: DateTime,
  ),
  results: [LocalSensitiveDataTargetResult(...)], // 每个目标的详细结果
)
```

### 6.3 备份保护

```dart
// 防止敏感数据通过云备份泄露
// mobile/lib/core/local_data_lifecycle/local_sensitive_data_backup_protection.dart
```

确保敏感数据不包含在：
- iCloud/Google 备份
- Android Auto Backup
- 开发者导出的调试日志

---

## 7. 威胁模型

### 7.1 威胁清单

| 威胁 | 攻击向量 | 影响 | 缓解措施 |
|-----|---------|-----|---------|
| JWT Token 泄露 | 设备被盗/root | 账户劫持 | 短 TTL + 自动刷新 |
| 中间人攻击 | 公共 WiFi | 数据窃听 | HTTPS + 建议证书固定 |
| 本地数据库读取 | root/越狱设备 | 儿童数据泄露 | 建议 Isar 加密 |
| 暴力破解 | 自动化工具 | 账户未授权访问 | 速率限制 + SMS 验证码 |
| 重放攻击 | 捕获 HTTP 请求 | 重复操作 | JWT nonce + 时间戳校验 |
| 数据残留 | 应用卸载后 | 隐私泄露 | 敏感数据清除机制 |
| LLM 注入 | 恶意输入 | 数据泄露到 LLM | 输入清理 + redactedSummary |

### 7.2 关键安全控制点

```
┌─────────────────────────────────────────────────────────┐
│                     Mobile App                           │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Input    │→ │ Validation   │→ │ Encryption       │   │
│  │ Sanitize │  │ Layer        │  │ (AES-256-GCM)    │   │
│  └──────────┘  └──────────────┘  └──────────────────┘   │
│        ↓                ↓                 ↓              │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Secure   │  │ Auth         │  │ Data Lifecycle   │   │
│  │ Storage  │  │ Headers      │  │ Manager          │   │
│  └──────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────┘
           │                │                 │
           ↓                ↓                 ↓
┌─────────────────────────────────────────────────────────┐
│                   API Gateway                            │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ TLS      │→ │ Rate Limiter │→ │ JWT Validator    │   │
│  │ Terminate│  │              │  │                  │   │
│  └──────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────┘
           │
           ↓
┌─────────────────────────────────────────────────────────┐
│                   Backend Services                       │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ AuthZ    │  │ Input        │  │ Audit Logger     │   │
│  │ (User    │  │ Validation   │  │                  │   │
│  │ Scoped)  │  │ (@Valid)     │  │                  │   │
│  └──────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 8. 审计与监控

### 8.1 安全事件监控

| 事件 | 监控方式 | 告警阈值 |
|-----|---------|---------|
| 登录失败 | 后端日志 + 指标 | 5 次/分钟/IP |
| Token 刷新失败 | 后端日志 | 连续 3 次/用户 |
| 数据清除操作 | 审计日志 | 每次记录 |
| 速率限制触发 | Gateway 日志 | 每次记录 |
| LLM 异常调用 | 后端日志 | 每次记录 |

### 8.2 合规审计点

- [ ] 每次 COPPA 同意变更记录
- [ ] 数据清除操作完整审计链
- [ ] JWT 签名密钥轮换记录
- [ ] API 速率限制配置审查
- [ ] 隐私政策版本更新记录
- [ ] 数据处理协议 (DPA) 签署记录

### 8.3 定期审查清单

| 频率 | 审查项 |
|-----|-------|
| 每月 | 速率限制配置、错误日志分析 |
| 每季度 | 密钥轮换、依赖安全更新、COPPA 合规检查 |
| 每年 | 隐私政策更新、完整安全审计、渗透测试 |

---

## 附录 A: 代码位置参考

| 安全组件 | 文件路径 |
|---------|---------|
| 认证拦截器 | `mobile/lib/core/network/auth_interceptor.dart` |
| Bearer Token 构建 | `mobile/lib/core/network/auth_headers.dart` |
| 本地安全存储 | `mobile/lib/features/account/data/local/account_local_store.dart` |
| 敏感数据清除 | `mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart` |
| 备份保护 | `mobile/lib/core/local_data_lifecycle/local_sensitive_data_backup_protection.dart` |
| 同意状态 | `mobile/lib/features/account/domain/models/account_consent_state.dart` |
| 会话模型 | `mobile/lib/features/account/domain/models/account_session.dart` |
| 清除注册器 | `mobile/lib/app/local_sensitive_data_clearance_registry.dart` |
| 速率限制 (后端) | `backend/gateway/src/main/java/.../RateLimiterConfig.java` |
| 清除报告测试 | `mobile/test/app/local_sensitive_data_clearance_registry_test.dart` |

---

## 附录 B: 优先修复项

| 优先级 | 项目 | 工作量 | 风险 |
|-------|-----|-------|-----|
| **P0** | 增加 COPPA 家长同意弹窗 | 中 | 合规风险 |
| **P0** | 记录同意时间戳和版本号 | 小 | 合规风险 |
| **P1** | Isar 数据库字段级加密 | 大 | 数据泄露 |
| **P1** | 证书固定 (Certificate Pinning) | 中 | 中间人攻击 |
| **P2** | JWT 非对称签名 (RS256) | 中 | Token 伪造 |
| **P2** | 定期同意重新确认机制 | 小 | 合规风险 |
| **P3** | 数据可携带/导出功能 | 大 | 用户权利 |
| **P3** | 渗透测试 | 大 | 综合安全 |
