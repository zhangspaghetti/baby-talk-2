package com.zhangspaghetti.babytalk.palace.projection;

import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface PalaceQueryTraceRepository extends JpaRepository<PalaceQueryTrace, UUID> {

    @Query("""
            select trace from PalaceQueryTrace trace
            order by trace.queriedAt desc
            """)
    List<PalaceQueryTrace> findRecent(Pageable pageable);
}
