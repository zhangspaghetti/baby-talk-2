# ── Stage 1: 构建 ──────────────────────────────────────────────
FROM maven:3-eclipse-temurin-17 AS builder

WORKDIR /app

# 先复制依赖描述文件，利用 Docker 层缓存
COPY pom.xml mvnw mvnw.cmd ./
COPY .mvn/ .mvn/

# 缓存依赖层（离线模式下载所有依赖）
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# 复制源码并打包
COPY src/ src/
RUN ./mvnw package -DskipTests -B

# ── Stage 2: 运行 ──────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine AS runtime

# 创建非 root 用户
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# 创建数据目录并赋权
RUN mkdir -p .data && chown appuser:appgroup .data

# 从构建阶段复制 JAR
COPY --from=builder /app/target/*.jar app.jar
RUN chown appuser:appgroup app.jar

USER appuser

EXPOSE 8080

# 健康检查（alpine 没有 curl，使用 wget）
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
