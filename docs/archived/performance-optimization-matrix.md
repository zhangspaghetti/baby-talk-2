# 查询优化矩阵

## 概述

本文档记录 BabyTalk 后端关键查询的优化策略，覆盖数据模型、索引、缓存三个维度。

## 热点链路分析

| 链路 | QPS 估算 | 延迟要求 | 瓶颈 |
|---|---|---|---|
| 用户登录 | 10/s | <200ms | DB 查询 + JWT 签发 |
| 练习记录上报 | 50/s | <500ms | DB 写入 + 去重 |
| 知识库检索 | 20/s | <300ms | 向量搜索 |
| Mentor 对话 | 5/s | <2s | AI 模型推理 |
| 家庭组状态 | 10/s | <200ms | DB 查询 |

## 优化矩阵

### 用户登录

| 维度 | 当前 | 优化 | 预期效果 |
|---|---|---|---|
| 数据模型 | 单表查询 | 复合索引 (username, status) | 查询 -50% |
| 索引 | username 单列索引 | (username, status, created_at) | 覆盖查询 |
| 缓存 | 无 | Redis 缓存 session (TTL 15min) | 命中率 >90% |

### 练习记录上报

| 维度 | 当前 | 优化 | 预期效果 |
|---|---|---|---|
| 数据模型 | 逐条插入 | 批量插入 (batch 100) | 写入 -80% |
| 索引 | eventKey 单列 | (installation_id, event_key) 复合 | 去重查询 -60% |
| 缓存 | 无 | Redis 布隆过滤器去重 | DB 查询 -90% |

### 知识库检索

| 维度 | 当前 | 优化 | 预期效果 |
|---|---|---|---|
| 数据模型 | 全表扫描 | HNSW 向量索引 | 查询 -95% |
| 索引 | 无 | ivfflat 索引 (lists=100) | 近似搜索 |
| 缓存 | 无 | Redis 缓存热门查询 (TTL 5min) | 命中率 >80% |

### Mentor 对话

| 维度 | 当前 | 优化 | 预期效果 |
|---|---|---|---|
| 数据模型 | 实时推理 | 流式响应 + 缓存相似问题 | 首 token -50% |
| 索引 | 无 | 问题 embedding 索引 | 相似问题检索 |
| 缓存 | 无 | Redis 缓存最近对话 (TTL 30min) | 重复问题 -70% |

### 家庭组状态

| 维度 | 当前 | 优化 | 预期效果 |
|---|---|---|---|
| 数据模型 | 多表 JOIN | 冗余字段 + 物化视图 | 查询 -70% |
| 索引 | household_id 单列 | (household_id, role, status) | 覆盖查询 |
| 缓存 | 无 | Redis 缓存 (TTL 5min, 主动失效) | 命中率 >95% |

## 索引审查清单

| 表 | 现有索引 | 建议索引 | 优先级 |
|---|---|---|---|
| admin_users | username | (username, status) | 高 |
| practice_events | event_key | (installation_id, event_key) | 高 |
| knowledge_chunks | 无 | ivfflat (embedding) | 高 |
| household_members | household_id | (household_id, role) | 中 |
| mentor_conversations | 无 | (user_id, created_at) | 中 |

## 缓存策略

| 数据 | TTL | 失效策略 | 容量 |
|---|---|---|---|
| Session | 15min | 登出/过期 | 10K keys |
| 热门知识库 | 5min | LRU | 1000 queries |
| 家庭组状态 | 5min | 主动失效 | 5K keys |
| Mentor 对话 | 30min | LRU | 500 conversations |
| 练习去重 | 1h | 布隆过滤器 | 1M events |
