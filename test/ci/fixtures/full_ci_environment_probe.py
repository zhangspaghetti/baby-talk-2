import json
import os
from pathlib import Path


SENSITIVE_NAMES = (
    "BABY_TALK_DB_URL",
    "BABY_TALK_DB_USERNAME",
    "BABY_TALK_DB_PASSWORD",
    "BABY_TALK_AI_API_KEY",
    "BABY_TALK_EMBEDDING_API_KEY",
    "BABY_TALK_MINIO_ACCESS_KEY",
    "BABY_TALK_MINIO_SECRET_KEY",
    "BABY_TALK_ADMIN_JWT_SECRET",
    "BABY_TALK_CONSUMER_JWT_SECRET",
    "BABY_TALK_PRACTICE_DISCOVERY_OWNER_KEY_SECRET",
    "BABY_TALK_MENTOR_PROVIDER_MODE",
    "BABY_TALK_REDIS_HOST",
    "BABY_TALK_UNRECOGNIZED_HOST_OVERRIDE",
    "SPRING_DATASOURCE_URL",
    "SPRING_DATASOURCE_USERNAME",
    "SPRING_DATASOURCE_PASSWORD",
    "SPRING_AI_OPENAI_API_KEY",
    "SPRING_AI_OPENAI_BASE_URL",
    "SPRING_CONFIG_LOCATION",
    "SPRING_CONFIG_IMPORT",
    "SPRING_PROFILES_ACTIVE",
    "SPRING_UNRECOGNIZED_HOST_OVERRIDE",
    "SPRING_APPLICATION_JSON",
    "DATABASE_URL",
    "JDBC_DATABASE_URL",
    "REDIS_URL",
    "DB_HOST",
    "DB_PASSWORD",
    "JDBC_URL",
    "MINIO_ENDPOINT",
    "MINIO_ACCESS_KEY",
    "MINIO_SECRET_KEY",
    "JWT_SECRET",
    "OPENAI_BASE_URL",
    "PGPASSWORD",
    "PGPASSFILE",
    "PGSERVICE",
    "JAVA_TOOL_OPTIONS",
    "_JAVA_OPTIONS",
    "JDK_JAVA_OPTIONS",
    "MAVEN_OPTS",
    "MAVEN_ARGS",
    "MAVEN_USER_HOME",
    "MAVEN_EXT_CLASS_PATH",
    "M2_HOME",
    "CLASSPATH",
    "MVNW_USERNAME",
    "MVNW_PASSWORD",
    "KUBE_TOKEN",
    "KUBE_CONTEXT",
    "KUBERNETES_SERVICE_HOST",
    "HELM_KUBEAPISERVER",
    "DOCKER_HOST",
    "DOCKER_CONTEXT",
    "TESTCONTAINERS_HOST_OVERRIDE",
    "GITHUB_TOKEN",
    "GH_TOKEN",
    "NPM_TOKEN",
    "CODECOV_TOKEN",
)


def main() -> None:
    kubeconfig = Path(os.environ.get("KUBECONFIG", ""))
    payload = {
        "leaked_names": sorted(name for name in SENSITIVE_NAMES if name in os.environ),
        "kubeconfig": str(kubeconfig),
        "kubeconfig_exists": kubeconfig.is_file(),
        "kubeconfig_text": kubeconfig.read_text(encoding="utf-8")
        if kubeconfig.is_file()
        else "",
        "ryuk_disabled": os.environ.get("TESTCONTAINERS_RYUK_DISABLED"),
        "download_sources": {
            "corepack": os.environ.get("COREPACK_NPM_REGISTRY"),
            "flutter": os.environ.get("FLUTTER_STORAGE_BASE_URL"),
            "npm": os.environ.get("NPM_CONFIG_REGISTRY"),
            "playwright": os.environ.get("PLAYWRIGHT_DOWNLOAD_HOST"),
            "pub": os.environ.get("PUB_HOSTED_URL"),
        },
    }
    print(json.dumps(payload, sort_keys=True))


if __name__ == "__main__":
    main()
