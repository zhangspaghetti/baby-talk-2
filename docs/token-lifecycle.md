# Token 生命周期

## 概述

BabyTalk 使用 JWT + Refresh Token 双令牌机制管理用户会话。

## Token 类型

| Token | 有效期 | 存储位置 | 用途 |
|---|---|---|---|
| Access Token | 15 分钟 | 内存（移动端）/ HttpOnly Cookie（Web） | API 请求鉴权 |
| Refresh Token | 7 天 | HttpOnly Cookie（Secure, SameSite=Strict） | 刷新 Access Token |

## 流程

### 1. 登录（Issue）

```
用户 → POST /api/admin/auth/login (username, password)
     → AdminAuthService.login()
     → JwtTokenService.generateAccessToken()  // 15min
     → RefreshTokenRepository.save()           // 7d
     → 返回 TokenPair (accessToken, refreshToken)
```

### 2. 刷新（Rotate）

```
客户端 → POST /api/admin/auth/refresh (refreshToken)
       → AdminAuthService.refresh()
       → 验证 refreshToken 有效性
       → 撤销旧 refreshToken（一次性使用，防止重放）
       → 颁发新 TokenPair（新 access + 新 refresh）
       → 返回新 TokenPair
```

**Rotate 策略**：
- Refresh Token 一次性使用：每次刷新后旧 token 立即失效
- 如果使用已撤销的 refresh token，返回 401 并撤销该用户所有 token（检测 token 泄露）
- 新 refresh token 有效期重新计算（7 天）
- 客户端应在 access token 过期前主动刷新，避免请求失败

### 3. 登出（Revoke）

```
客户端 → POST /api/admin/auth/logout (refreshToken)
       → AdminAuthService.logout()
       → RefreshTokenRepository.revokeAllByUserId()
       → 清空该用户所有 refresh token
```

**Revoke 链路**：
- 单个 refresh token 撤销：标记为 revoked，不再可用于刷新
- 用户级全量撤销：登出时撤销该用户所有 refresh token
- 异常检测撤销：如果检测到已撤销的 token 被使用，撤销该用户所有 token
- 撤销后，客户端必须重新登录获取新 token 对

## 安全要求

- Refresh Token 必须存储在 HttpOnly Cookie 中，防止 XSS 访问
- Cookie 属性：`Secure=true`, `SameSite=Strict`, `Max-Age=604800`
- Access Token 过期后，客户端使用 Refresh Token 获取新 Token 对
- Refresh Token 使用一次即失效（Rotate 策略）
- 登出时撤销所有 Refresh Token

## 端到端测试覆盖

- [ ] 登录成功返回 TokenPair
- [ ] 使用过期 Access Token 返回 401
- [ ] 使用有效 Refresh Token 返回新 TokenPair
- [ ] 使用已撤销的 Refresh Token 返回 401
- [ ] 登出后所有 Refresh Token 失效
