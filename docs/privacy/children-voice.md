# 儿童语音隐私合规

## 概述

BabyTalk 涉及儿童语音数据采集，需严格遵守儿童隐私保护法规。

## 数据分级标准

| 级别 | 数据类型 | 处理要求 |
|---|---|---|
| Level 1 - 原始语音 | 录音文件（WAV/MP3） | AES-256 加密存储，≤30 天留存，访问需审计 |
| Level 2 - 转写文本 | 语音转文字结果 | 脱敏处理，≤90 天留存 |
| Level 3 - 聚合指标 | 统计数据（无个人标识） | 可长期保留 |

## 加密实现

### 存储加密

- **算法**: AES-256-GCM
- **密钥管理**: 环境变量 `BABY_TALK_VOICE_ENCRYPTION_KEY`，定期轮换
- **实现**: `common/.../VoiceEncryptor.java`

```java
// 加密流程
plaintext → AES-256-GCM(key, iv) → ciphertext + authTag

// 解密流程
ciphertext + authTag → AES-256-GCM(key, iv) → plaintext
```

### 传输加密

- HTTPS 强制（TLS 1.2+）
- API 响应不返回原始语音文件 URL

## 访问审计

| 操作 | 审计内容 | 存储 |
|---|---|---|
| 语音采集 | child_id, timestamp, duration, device_info | 审计日志 |
| 语音播放 | admin_id, child_id, timestamp, reason | 审计日志 |
| 语音导出 | admin_id, child_id, timestamp, format, destination | 审计日志 |
| 语音删除 | admin_id, child_id, timestamp, reason | 审计日志 |

### 审计接口

```java
// common/.../VoiceAuditService.java
public interface VoiceAuditService {
    void logAccess(VoiceAccessEvent event);
    List<VoiceAccessEvent> queryAuditLog(String childId, Instant from, Instant to);
}
```

## 留存策略

| 数据级别 | 留存期限 | 过期处理 |
|---|---|---|
| Level 1 - 原始语音 | ≤30 天 | 自动删除 + 审计记录 |
| Level 2 - 转写文本 | ≤90 天 | 自动脱敏 + 审计记录 |
| Level 3 - 聚合指标 | 无限期 | N/A |

### 自动清理

```sql
-- Flyway 迁移脚本：定期清理过期语音数据
DELETE FROM voice_recordings
WHERE created_at < NOW() - INTERVAL '30 days';
```

## 家长权利

- **知情权**: 明确告知采集内容和用途
- **同意权**: 需家长明确同意后才开始采集
- **访问权**: 家长可查看/导出孩子的语音数据
- **删除权**: 家长可随时删除孩子的语音数据
- **撤回同意**: 撤回同意后立即停止采集并删除数据

## 法务 Review Checklist

- [ ] 数据分级标准符合《儿童个人信息网络保护规定》
- [ ] 加密实现通过安全审计
- [ ] 留存期限不超过法规要求
- [ ] 家长权利接口完整可用
- [ ] 审计日志不可篡改
- [ ] 数据删除可验证
