#ifndef SERVO_H
#define SERVO_H

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t servo_init(void);
esp_err_t servo_set_angle(int angle);

#ifdef __cplusplus
}
#endif

#endif

