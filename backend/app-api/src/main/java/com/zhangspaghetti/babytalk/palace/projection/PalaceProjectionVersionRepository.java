package com.zhangspaghetti.babytalk.palace.projection;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface PalaceProjectionVersionRepository extends JpaRepository<PalaceProjectionVersion, UUID> {

    @Query(value = """
            select *
            from palace_projection_version
            where status = 'current'
            order by version_num desc
            limit 1
            """, nativeQuery = true)
    Optional<PalaceProjectionVersion> findCurrentVersion();

    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = """
            update palace_projection_version
            set version_num = version_num + 1
            where id = :id
            """, nativeQuery = true)
    int incrementVersion(@Param("id") UUID id);
}
