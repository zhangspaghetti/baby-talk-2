# 外部 API 授权矩阵

## 概述

BabyTalk 集成多个外部 API。本文档记录每个外部 API 的 token 持有者、授权范围、失败降级策略。

## 外部 API 列表

| 服务 | 用途 | Token 持有者 | 授权范围 |
|---|---|---|---|
| MinIO | 对象存储（语音/文档） | 服务端 | 读写指定 bucket |
| Redis | 缓存/会话/限流 | 服务端 | 全局访问 |
| PostgreSQL | 数据库 | 服务端 | 全局访问 |
| Spring AI | AI 模型调用 | 服务端 | 模型推理 |
| 微信开放平台 | 分享/登录 | 服务端 | 用户信息/分享 |

## 详细矩阵

### MinIO（对象存储）

| 项目 | 值 |
|---|---|
| Token 类型 | Access Key + Secret Key |
| 持有者 | 服务端（环境变量） |
| 授权范围 | `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` |
| 轮换策略 | 每 90 天轮换 |
| 失败降级 | 返回 503，客户端重试 |
| 审计 | 记录所有读写操作 |

### Redis（缓存）

| 项目 | 值 |
|---|---|
| Token 类型 | 密码认证 |
| 持有者 | 服务端（环境变量） |
| 授权范围 | 全局读写 |
| 轮换策略 | 每 90 天轮换 |
| 失败降级 | 降级为无缓存模式，返回 503 |
| 审计 | 不审计（缓存层） |

### PostgreSQL（数据库）

| 项目 | 值 |
|---|---|
| Token 类型 | 用户名+密码 |
| 持有者 | 服务端（环境变量） |
| 授权范围 | 全局读写 |
| 轮换策略 | 每 90 天轮换 |
| 失败降级 | 返回 500，告警 |
| 审计 | 通过 Flyway 迁移记录 |

### Spring AI（AI 模型）

| 项目 | 值 |
|---|---|
| Token 类型 | API Key |
| 持有者 | 服务端（环境变量） |
| 授权范围 | 模型推理 |
| 轮换策略 | 按需轮换 |
| 失败降级 | 降级为规则引擎，返回 fallback 响应 |
| 审计 | 记录调用次数/延迟 |

### 微信开放平台

| 项目 | 值 |
|---|---|
| Token 类型 | AppID + AppSecret |
| 持有者 | 服务端（环境变量） |
| 授权范围 | 用户信息、分享接口 |
| 轮换策略 | 按需轮换 |
| 失败降级 | 降级为无分享功能 |
| 审计 | 记录调用次数 |

## 环境变量清单

| 变量名 | 服务 | 说明 |
|---|---|---|
| `BABY_TALK_MINIO_ENDPOINT` | MinIO | 服务端点 |
| `BABY_TALK_MINIO_ACCESS_KEY` | MinIO | 访问密钥 |
| `BABY_TALK_MINIO_SECRET_KEY` | MinIO | 秘密密钥 |
| `BABY_TALK_REDIS_HOST` | Redis | 主机地址 |
| `BABY_TALK_REDIS_PASSWORD` | Redis | 认证密码 |
| `BABY_TALK_DB_URL` | PostgreSQL | 连接字符串 |
| `BABY_TALK_AI_API_KEY` | Spring AI | API 密钥 |
| `BABY_TALK_WECHAT_APP_ID` | 微信 | 应用 ID |
| `BABY_TALK_WECHAT_APP_SECRET` | 微信 | 应用密钥 |

## 安全要求

- 所有密钥通过环境变量注入，禁止硬编码
- 生产环境使用密钥管理服务（如 Vault）
- 定期轮换密钥（每 90 天）
- 失败时返回统一错误格式，不暴露内部细节
