#ifndef CAT_DETECTOR_H
#define CAT_DETECTOR_H

#include "behavior_engine.h"

#include "esp_camera.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t cat_detector_init(void);
esp_err_t cat_detector_detect(camera_fb_t *fb, cat_detection_t *out_detection);

#ifdef __cplusplus
}
#endif

#endif

