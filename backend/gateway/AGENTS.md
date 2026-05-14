# GATEWAY

Spring Cloud Gateway 网关服务。

## STRUCTURE

```
gateway/
├── src/main/java/com/zhangspaghetti/babytalk/gateway/
│   └── GatewayApplication.java
└── src/main/resources/
    └── application.yml
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 路由配置 | `application.yml` | 路由规则、过滤器 |
| 限流 | `application.yml` | IP / user / endpoint 三维限流 |
| 启动类 | `GatewayApplication.java` | 排除 datasource/jpa/flyway 自动配置 |

## CONVENTIONS

- **路由**：Spring Cloud Gateway 路由规则
- **限流**：三维限流（IP / user / endpoint）
- **排除自动配置**：GatewayApplication 排除 datasource/jpa/flyway
