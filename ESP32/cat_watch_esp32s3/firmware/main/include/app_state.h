#ifndef APP_STATE_H
#define APP_STATE_H

#include "behavior_engine.h"

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    behavior_engine_t behavior;
    int servo_angle;
    bool wifi_connected;
    uint32_t last_frame_ms;
} app_state_t;

void app_state_init(void);
app_state_t *app_state_get(void);
void app_state_lock(void);
void app_state_unlock(void);

#ifdef __cplusplus
}
#endif

#endif

