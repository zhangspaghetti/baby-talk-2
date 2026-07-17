package com.zhangspaghetti.babytalk.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.http.converter.json.JacksonJsonHttpMessageConverter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter;

@SpringBootTest(classes = Jackson3ContractTest.TestApplication.class)
@AutoConfigureMockMvc(addFilters = false)
class Jackson3ContractTest {

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private RequestMappingHandlerAdapter handlerAdapter;

    @Autowired
    private MockMvc mockMvc;

    @Test
    void bootManagedMapperAndMvcConverterUseJackson3() {
        assertThat(objectMapper.getClass().getPackageName()).startsWith("tools.jackson");
        assertThat(handlerAdapter.getMessageConverters())
                .filteredOn(converter -> converter.getClass().equals(JacksonJsonHttpMessageConverter.class))
                .singleElement()
                .satisfies(converter -> assertThat(
                        ((JacksonJsonHttpMessageConverter) converter).getMapper()
                ).isSameAs(objectMapper));
        assertThat(handlerAdapter.getMessageConverters())
                .noneMatch(converter -> converter.getClass().getName().contains("MappingJackson2"));
    }

    @Test
    void mvcWritesJackson3JsonOnTheHttpWire() throws Exception {
        mockMvc.perform(get("/jackson3-contract"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("application/json"))
                .andExpect(jsonPath("$.contractValue").value("jackson3"));
    }

    @Configuration(proxyBeanMethods = false)
    @EnableAutoConfiguration(excludeName = {
            "org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration",
            "com.alibaba.druid.spring.boot4.autoconfigure.DruidDataSourceAutoConfigure"
    })
    @Import(ContractController.class)
    static class TestApplication {
    }

    @RestController
    static class ContractController {

        @GetMapping("/jackson3-contract")
        ContractPayload contract() {
            return new ContractPayload("jackson3");
        }
    }

    record ContractPayload(String contractValue) {
    }
}
