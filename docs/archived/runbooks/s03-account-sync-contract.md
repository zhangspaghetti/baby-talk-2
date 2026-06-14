# S03 账号 / 同意 / append-only 同步合同运行手册

## 目标

S03 后端提供 4 类真实边界：

1. **Auth challenge / verify**：手机号请求验证码、验证码换取 session。
2. **Consent accept / revoke / delete**：同意、撤回、删除都留下审计轨迹。
3. **Append-only event ingest**：客户端按稳定 `eventKey = installationId:localEventId` 上传练习事件；服务端只追加，不做 last-write-wins 聚合覆盖。
4. **Bootstrap restore**：同 installation 重登后可取回服务端事件，供移动端重新派生 recent result / resume。

## 环境变量合同

| Key | 默认值 | 说明 |
|---|---|---|
| `BABY_TALK_DB_URL` | `jdbc:h2:file:./.data/babytalk;MODE=PostgreSQL;AUTO_SERVER=TRUE;DATABASE_TO_UPPER=false` | 本地开发默认 H2 文件库；生产应替换为 PostgreSQL JDBC URL。 |
| `BABY_TALK_DB_USERNAME` | `sa` | 数据库用户名。 |
| `BABY_TALK_DB_PASSWORD` | 空 | 数据库密码。 |
| `BABY_TALK_MIN_SUPPORTED_VERSION` | `1.2.0` | 最低可接受客户端版本；低于该版本返回 `426 Upgrade Required`。 |
| `BABY_TALK_UPGRADE_URL` | `https://example.com/baby-talk/download` | 426 返回头与响应体中的升级地址。 |
| `BABY_TALK_SYNC_MAX_BATCH_SIZE` | `100` | 单次 sync batch 上限；超过直接 400。 |
| `BABY_TALK_BOOTSTRAP_MAX_EVENTS` | `200` | 单次 bootstrap 返回的最大事件数。 |
| `BABY_TALK_SMS_PROVIDER_MODE` | `dev` | `dev` 为本地 stub；其他值当前明确返回 `sms_provider_unconfigured`。 |
| `BABY_TALK_SMS_DEV_CODE` | `246810` | dev stub 用的固定验证码；必须是 4-8 位数字。 |
| `BABY_TALK_SMS_CHALLENGE_TTL` | `PT5M` | 验证码过期时间。 |
| `BABY_TALK_SMS_SIMULATE_TIMEOUT` | `false` | 置为 `true` 时模拟短信上游超时，接口返回可重试错误。 |

## API 合同

所有 `/api/**` 请求都必须带 `X-App-Version`。缺失或低于最低版本时返回：

- HTTP `426 Upgrade Required`
- Header: `X-Min-Supported-Version`
- Header: `X-Upgrade-Url`
- Body: `code=app_version_required` 或 `code=app_version_unsupported`

### 1) 请求验证码

`POST /api/v1/auth/challenges`

```json
{
  "phoneNumber": "13800138000"
}
```

成功返回：

```json
{
  "challengeId": "challenge_xxx",
  "maskedPhoneNumber": "138****8000",
  "codeLength": 6,
  "expiresAt": "2026-04-09T02:00:00Z"
}
```

### 2) 验证码换 session

`POST /api/v1/auth/verify`

```json
{
  "challengeId": "challenge_xxx",
  "verificationCode": "246810",
  "installationId": "install-alpha"
}
```

成功返回：

```json
{
  "accountId": "acct_xxx",
  "sessionId": "sess_xxx",
  "maskedPhoneNumber": "138****8000",
  "createdAt": "2026-04-09T02:00:00Z",
  "consentStatus": "signed_out"
}
```

### 3) 接受同意

`POST /api/v1/consent/accept`

Header: `X-Session-Id: sess_xxx`

```json
{
  "consentVersion": "pipl-v1"
}
```

### 4) 撤回同意

`POST /api/v1/consent/revoke`

Header: `X-Session-Id: sess_xxx`

```json
{
  "reason": "user_requested"
}
```

撤回会：

- 将账号同意状态改为 `revoked`
- 将该账号所有 session 改为 `revoked`
- 写入 `consent_audit_logs`
- 后续同 session 的 bootstrap / sync 返回 `409 consent_revoked`

### 5) 删除账号

`DELETE /api/v1/account`

Header: `X-Session-Id: sess_xxx`

```json
{
  "reason": "forget_me"
}
```

删除会：

- 删除该账号的 `interaction_events`
- 将 `accounts` 行 tombstone 成 `status=deleted`
- 将该账号所有 session 改为 `deleted`
- 写入 `consent_audit_logs`
- 同 session 的 bootstrap 返回 `410 account_deleted`
- 同手机号可重新请求 challenge / verify，生成新的活跃账号

### 6) Append-only 批量同步

`POST /api/v1/sync/events`

Header: `X-Session-Id: sess_xxx`

```json
{
  "installationId": "install-alpha",
  "events": [
    {
      "eventKey": "install-alpha:evt_1",
      "localEventId": "evt_1",
      "installationId": "install-alpha",
      "spaceId": "daily_care",
      "activityId": "bath_time",
      "phraseId": "bath_time_warm_water",
      "reactionType": "calm",
      "clientTimestamp": "2026-04-09T02:00:00Z"
    }
  ]
}
```

返回：

- `acceptedCount`
- `duplicateCount`
- `acceptedEventKeys`
- `duplicateEventKeys`

约束：

- `eventKey` 必须等于 `installationId:localEventId`
- 同 batch 内重复 key 直接 400
- 数据库写失败会整批回滚，不保留半成功
- 已存在 key 按 duplicate 处理，保持幂等

### 7) Bootstrap 恢复

`GET /api/v1/bootstrap?installationId=install-alpha`

Header: `X-Session-Id: sess_xxx`

返回该 installation 的 append-only 事件列表；移动端应继续使用本地 `PracticeRepository` 从事件派生 recent result / resume，而不是让服务端返回 last-write-wins 聚合快照。

## 诊断与可观察性

- **版本问题**：看 `426` + `X-Min-Supported-Version` / `X-Upgrade-Url`。
- **鉴权问题**：`invalid_session` / `consent_required` / `consent_revoked` / `account_deleted`。
- **同步问题**：`acceptedCount` / `duplicateCount` / `sync_batch_rejected.details.failedEventKey`。
- **合规问题**：`consent_audit_logs` 里可看到 `accept/revoke/delete` 的 `applied/duplicate` 结果。

## Redaction 规则

- 响应体不返回原始手机号、验证码、token。
- 仅返回 `maskedPhoneNumber`。
- 错误细节里不拼接手机号、验证码、session secret。
- `interaction_events` 只保存事实字段与 sync metadata，不保存同意前宝宝 PII。

## 本地开发 / 测试

```bash
mvn -f backend/pom.xml test
```

关键 proof：

- `ApiVersionHandshakeWebTest`
- `AuthConsentSyncWebTest`
- `AuthConsentSyncServiceTest`
