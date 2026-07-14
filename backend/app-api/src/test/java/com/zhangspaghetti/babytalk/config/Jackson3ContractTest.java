package com.zhangspaghetti.babytalk.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class Jackson3ContractTest {

    @Test
    void bootUsesJackson3JsonMapper() {
        var mapper = JsonMapper.builder().build();
        assertThat(mapper.getClass().getPackageName()).startsWith("tools.jackson");
    }
}
