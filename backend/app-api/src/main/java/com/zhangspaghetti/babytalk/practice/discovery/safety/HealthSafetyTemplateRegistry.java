package com.zhangspaghetti.babytalk.practice.discovery.safety;

import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public final class HealthSafetyTemplateRegistry {

    private final Map<String, CustomSceneSafetyProperties.Template> templates;
    private final Set<String> templateIds;

    public HealthSafetyTemplateRegistry() {
        this(CustomSceneSafetyProperties.defaults());
    }

    @Autowired
    public HealthSafetyTemplateRegistry(CustomSceneSafetyProperties properties) {
        this.templates = properties.templates();
        this.templateIds = Collections.unmodifiableSet(new LinkedHashSet<>(templates.keySet()));
    }

    public CustomSceneSafetyProperties.Template template(String templateId) {
        if (templateId == null || templateId.isBlank()) {
            throw new IllegalArgumentException("health safety template id must not be blank");
        }
        var template = templates.get(templateId.trim());
        if (template == null) {
            throw new IllegalArgumentException("unknown health safety template");
        }
        return template;
    }

    public Set<String> templateIds() {
        return templateIds;
    }

}
