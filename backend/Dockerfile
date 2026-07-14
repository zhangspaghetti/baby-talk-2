FROM maven:3-eclipse-temurin-21 AS builder

ARG MODULE=app-api
WORKDIR /app

COPY .mvn/ .mvn/
COPY pom.xml ./pom.xml
COPY common/pom.xml common/pom.xml
COPY app-api/pom.xml app-api/pom.xml
COPY admin-api/pom.xml admin-api/pom.xml
COPY gateway/pom.xml gateway/pom.xml
COPY db-migration/pom.xml db-migration/pom.xml
RUN mvn -pl ${MODULE} -am dependency:go-offline -B

COPY . .
RUN mvn -pl ${MODULE} -am package -DskipTests -B \
 && find ${MODULE}/target -maxdepth 1 -type f -name '*.jar' ! -name '*.original' -exec cp {} /tmp/app.jar \;

FROM eclipse-temurin:21-jre-alpine AS runtime

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app

COPY --from=builder /tmp/app.jar /app/app.jar
RUN chown appuser:appgroup /app/app.jar

USER appuser

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
