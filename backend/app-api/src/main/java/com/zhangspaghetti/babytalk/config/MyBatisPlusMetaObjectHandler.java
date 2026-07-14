package com.zhangspaghetti.babytalk.config;

import com.baomidou.mybatisplus.core.handlers.MetaObjectHandler;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.apache.ibatis.reflection.MetaObject;
import org.springframework.stereotype.Component;

@Component
public class MyBatisPlusMetaObjectHandler implements MetaObjectHandler {

    @Override
    public void insertFill(MetaObject metaObject) {
        var now = OffsetDateTime.now(ZoneOffset.UTC);
        strictInsertFill(metaObject, "createdAt", OffsetDateTime.class, now);
        strictInsertFill(metaObject, "updatedAt", OffsetDateTime.class, now);
    }

    @Override
    public void updateFill(MetaObject metaObject) {
        strictUpdateFill(metaObject, "updatedAt", OffsetDateTime.class, OffsetDateTime.now(ZoneOffset.UTC));
    }
}
