package com.zhangspaghetti.babytalk.admin.rbac;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

public class AdminPermissionCatalog {

    public static final String USERS_READ = "users:read";
    public static final String USERS_WRITE = "users:write";
    public static final String ADMINS_READ = "admins:read";
    public static final String ADMINS_WRITE = "admins:write";
    public static final String RBAC_READ = "rbac:read";
    public static final String RBAC_WRITE = "rbac:write";
    public static final String RAG_READ = "rag:read";
    public static final String RAG_WRITE = "rag:write";
    public static final String KG_READ = "kg:read";
    public static final String KG_REVIEW = "kg:review";
    public static final String MENTOR_AUDIT = "mentor:audit";
    public static final String DISTRIBUTION_READ = "distribution:read";

    private final List<PermissionDefinition> definitions = List.of(
            new PermissionDefinition(USERS_READ, "Read consumer users."),
            new PermissionDefinition(USERS_WRITE, "Manage consumer users."),
            new PermissionDefinition(ADMINS_READ, "Read admin principals."),
            new PermissionDefinition(ADMINS_WRITE, "Manage admin principals."),
            new PermissionDefinition(RBAC_READ, "Read admin roles and permissions."),
            new PermissionDefinition(RBAC_WRITE, "Manage admin roles and permissions."),
            new PermissionDefinition(RAG_READ, "Read RAG resources."),
            new PermissionDefinition(RAG_WRITE, "Manage RAG resources."),
            new PermissionDefinition(KG_READ, "Read knowledge graph data."),
            new PermissionDefinition(KG_REVIEW, "Review knowledge graph changes."),
            new PermissionDefinition(MENTOR_AUDIT, "Audit mentor operations."),
            new PermissionDefinition(DISTRIBUTION_READ, "Read distribution reports.")
    );

    private final Map<String, PermissionDefinition> definitionsByCode = definitions.stream()
            .collect(Collectors.toUnmodifiableMap(PermissionDefinition::code, Function.identity()));

    public List<PermissionDefinition> definitions() {
        return definitions;
    }

    public List<String> codes() {
        return definitions.stream()
                .map(PermissionDefinition::code)
                .toList();
    }

    public boolean contains(String code) {
        return definitionsByCode.containsKey(code);
    }

    public Optional<PermissionDefinition> findByCode(String code) {
        return Optional.ofNullable(definitionsByCode.get(code));
    }

    public record PermissionDefinition(String code, String description) {
    }
}
