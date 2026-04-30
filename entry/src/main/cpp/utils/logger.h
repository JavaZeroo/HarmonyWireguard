#ifndef LOGGER_H
#define LOGGER_H

#include <hilog/log.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0000
#define LOG_TAG "WireGuard"

#define WG_LOGI(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[%{public}s %{public}d] " fmt, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#define WG_LOGE(fmt, ...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "[%{public}s %{public}d] " fmt, __FUNCTION__, __LINE__, ##__VA_ARGS__)

#endif // LOGGER_H
