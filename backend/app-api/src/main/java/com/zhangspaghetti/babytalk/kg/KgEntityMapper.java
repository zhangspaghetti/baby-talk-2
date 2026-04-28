package com.zhangspaghetti.babytalk.kg;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface KgEntityMapper {

    void insert(@Param("entity") KgEntity entity);

    KgEntity findById(@Param("id") UUID id);

    List<KgEntity> findByNameLike(
            @Param("query") String query,
            @Param("searchPattern") String searchPattern
    );

    List<KgEntity> findByWingAndRoom(
            @Param("wing") String wing,
            @Param("room") String room
    );

    int update(
            @Param("entity") KgEntity entity,
            @Param("updatedAt") Instant updatedAt
    );
}
