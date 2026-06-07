#include "app_state.h"

#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

#include "sdkconfig.h"

static app_state_t s_state;
static StaticSemaphore_t s_mutex_buf;
static SemaphoreHandle_t s_mutex;

void app_state_init(void)
{
    s_mutex = xSemaphoreCreateMutexStatic(&s_mutex_buf);
    behavior_engine_init(&s_state.behavior, CONFIG_CATWATCH_CAMERA_FRAME_WIDTH, CONFIG_CATWATCH_CAMERA_FRAME_HEIGHT);
    s_state.servo_angle = 90;
}

app_state_t *app_state_get(void)
{
    return &s_state;
}

void app_state_lock(void)
{
    xSemaphoreTake(s_mutex, portMAX_DELAY);
}

void app_state_unlock(void)
{
    xSemaphoreGive(s_mutex);
}

