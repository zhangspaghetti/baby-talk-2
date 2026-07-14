package com.zhangspaghetti.babytalk.practice.catalog;

import static org.assertj.core.api.Assertions.assertThat;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import java.lang.reflect.Method;
import java.util.Arrays;
import org.junit.jupiter.api.Test;

class PracticeCatalogMapperTest {

    @Test
    void mapperContainsSqlContractOnly() {
        assertThat(BaseMapper.class.isAssignableFrom(PracticeCatalogMapper.class)).isFalse();
        assertThat(Arrays.stream(PracticeCatalogMapper.class.getDeclaredMethods())
                .map(Method::isDefault))
                .doesNotContain(true);
    }
}
