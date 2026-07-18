package com.zhangspaghetti.babytalk.practice.generated.evidence;

import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceBundleEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceItemEntity;
import java.util.List;

public interface EvidenceBundlePersistencePort {

    void persistBundleWithItems(
            PracticeEvidenceBundleEntity bundle,
            List<PracticeEvidenceItemEntity> items);
}
