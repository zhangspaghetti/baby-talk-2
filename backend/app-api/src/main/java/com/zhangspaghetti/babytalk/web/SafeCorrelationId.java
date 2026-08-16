package com.zhangspaghetti.babytalk.web;

import java.util.UUID;

/** Opaque support handle. It carries no request, account, or exception data. */
public final class SafeCorrelationId {

    private SafeCorrelationId() {
    }

    public static String create() {
        return "err_" + UUID.randomUUID().toString().replace("-", "");
    }
}
