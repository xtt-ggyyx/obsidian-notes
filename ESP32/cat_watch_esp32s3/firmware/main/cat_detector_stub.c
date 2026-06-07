#include "cat_detector.h"

#include "sdkconfig.h"

esp_err_t cat_detector_init(void)
{
    return ESP_OK;
}

esp_err_t cat_detector_detect(camera_fb_t *fb, cat_detection_t *out_detection)
{
    (void)fb;
    out_detection->found = false;
    out_detection->score = 0.0f;
    out_detection->box = (cat_rect_t){0, 0, 0, 0};
    return ESP_OK;
}

