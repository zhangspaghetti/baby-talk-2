# DB Migration 评审清单

## 概述

Flyway 迁移在 10× 容量下可能卡住。本文档提供迁移评审清单，确保迁移安全执行。

## 评审清单

### 迁移前检查

- [ ] **迁移类型确认**: DDL / DML / 存储过程
- [ ] **影响范围**: 表名、行数估算、锁范围
- [ ] **回滚方案**: 是否可回滚、回滚脚本
- [ ] **数据备份**: 备份策略、恢复时间
- [ ] **维护窗口**: 是否需要维护窗口

### DDL 迁移检查

- [ ] **大表 ALTER**: >100 万行的表使用在线 DDL
- [ ] **索引创建**: 使用 `CREATE INDEX CONCURRENTLY`
- [ ] **列添加**: 默认值处理、NOT NULL 约束
- [ ] **表重命名**: 依赖关系检查
- [ ] **外键约束**: 延迟约束检查

### DML 迁移检查

- [ ] **批量大小**: 每批 1000-5000 行
- [ ] **事务大小**: 避免长事务
- [ ] **锁策略**: 行级锁 vs 表级锁
- [ ] **进度监控**: 是否有进度反馈
- [ ] **幂等性**: 是否可重复执行

### 性能检查

- [ ] **执行时间估算**: 基于数据量估算
- [ ] **索引影响**: 是否影响现有索引
- [ ] **并发影响**: 是否阻塞其他操作
- [ ] **资源消耗**: CPU / 内存 / 磁盘 IO

## 高风险迁移处理

### 大表 ALTER

```sql
-- 错误: 直接 ALTER 会锁表
ALTER TABLE big_table ADD COLUMN new_col VARCHAR(100);

-- 正确: 使用在线 DDL
-- PostgreSQL 12+ 支持在线 ADD COLUMN
ALTER TABLE big_table ADD COLUMN new_col VARCHAR(100) DEFAULT NULL;
```

### 大表索引创建

```sql
-- 错误: 会锁表
CREATE INDEX idx_big_table_col ON big_table(col);

-- 正确: 使用 CONCURRENTLY
CREATE INDEX CONCURRENTLY idx_big_table_col ON big_table(col);
```

### 数据迁移

```sql
-- 错误: 一次性更新所有行
UPDATE big_table SET status = 'new' WHERE status = 'old';

-- 正确: 分批更新
UPDATE big_table SET status = 'new'
WHERE id IN (
  SELECT id FROM big_table
  WHERE status = 'old'
  LIMIT 1000
);
```

## 影子库演练

### 演练步骤

1. **创建影子库**: 从生产库快照创建
2. **执行迁移**: 在影子库执行迁移
3. **验证数据**: 检查数据完整性
4. **性能测试**: 测试迁移后查询性能
5. **回滚测试**: 测试回滚脚本

### 演练检查清单

- [ ] 影子库创建成功
- [ ] 迁移执行成功
- [ ] 数据完整性验证通过
- [ ] 查询性能无退化
- [ ] 回滚脚本可用

## 迁移评审模板

```markdown
## 迁移评审: [迁移名称]

### 基本信息
- 迁移文件: V{version}__{description}.sql
- 影响表: [表名]
- 预计行数: [行数]
- 预计时间: [时间]

### 变更内容
- [ ] DDL 变更
- [ ] DML 变更
- [ ] 索引变更

### 风险评估
- [ ] 低风险
- [ ] 中风险
- [ ] 高风险

### 评审意见
- 评审人: [姓名]
- 日期: [日期]
- 结论: [通过/拒绝/需修改]
```
