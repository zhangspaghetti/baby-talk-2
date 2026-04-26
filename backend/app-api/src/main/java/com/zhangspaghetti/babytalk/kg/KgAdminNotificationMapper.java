package com.zhangspaghetti.babytalk.kg;

import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface KgAdminNotificationMapper {

    void insert(@Param("notification") KgAdminNotification notification);

    List<KgAdminNotification> findUnread();

    int markRead(@Param("id") UUID id);

    List<KgAdminNotification> findAll();

    KgAdminNotification findById(@Param("id") UUID id);

    List<KgAdminNotification> findByContradictionId(@Param("contradictionId") UUID contradictionId);
}
