#ifndef CAMERA_OV3660_H
#define CAMERA_OV3660_H

#include "esp_camera.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t camera_ov3660_init(void);
camera_fb_t *camera_ov3660_capture(void);
void camera_ov3660_return(camera_fb_t *fb);

#ifdef __cplusplus
}
#endif

#endif

