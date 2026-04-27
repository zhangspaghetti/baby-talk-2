package com.zhangspaghetti.babytalk.service;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface ShareLandingMapper {

    void insertShareCard(@Param("row") ShareLandingRepository.ShareCardRow row);

    ShareLandingRepository.ShareCardRow findByToken(@Param("token") String token);

    void insertEvent(@Param("row") ShareLandingRepository.EventRow row);
}
