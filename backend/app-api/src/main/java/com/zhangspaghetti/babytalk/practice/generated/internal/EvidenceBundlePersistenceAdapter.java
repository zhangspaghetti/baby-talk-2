package com.zhangspaghetti.babytalk.practice.generated.internal;

import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceBundlePersistencePort;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceBundleEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceItemEntity;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
class EvidenceBundlePersistenceAdapter implements EvidenceBundlePersistencePort {

    private final PracticeGenerationAuditMapper auditMapper;

    EvidenceBundlePersistenceAdapter(PracticeGenerationAuditMapper auditMapper) {
        this.auditMapper = auditMapper;
    }

    @Override
    @Transactional
    public void persistBundleWithItems(
            PracticeEvidenceBundleEntity bundle,
            List<PracticeEvidenceItemEntity> items
    ) {
        auditMapper.insertEvidenceBundle(bundle);
        auditMapper.insertEvidenceItems(items);
    }
}
