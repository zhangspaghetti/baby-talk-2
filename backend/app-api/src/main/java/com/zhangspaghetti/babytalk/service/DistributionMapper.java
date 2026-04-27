package com.zhangspaghetti.babytalk.service;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface DistributionMapper {

    void insertEvent(@Param("row") DistributionRepository.EventRow row);

    List<DistributionRepository.EventRow> listRecentEvents();
}
