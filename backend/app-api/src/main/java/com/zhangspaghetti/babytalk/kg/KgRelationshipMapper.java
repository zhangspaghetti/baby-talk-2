package com.zhangspaghetti.babytalk.kg;

import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface KgRelationshipMapper {

    void insert(@Param("relationship") KgRelationship relationship);

    KgRelationship findById(@Param("id") UUID id);

    List<KgRelationship> findBySourceEntityId(@Param("sourceEntityId") UUID sourceEntityId);

    List<KgRelationship> findByTargetEntityId(@Param("targetEntityId") UUID targetEntityId);

    List<KgRelationship> findByRelationType(@Param("relationType") String relationType);

    List<KgRelationship> findContradictionCandidatesForEntity(@Param("targetEntityId") UUID targetEntityId);
}
