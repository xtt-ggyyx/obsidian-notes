#include "servo.h"

#include "app_state.h"

#include "driver/ledc.h"

#define SERVO_GPIO 47
#define SERVO_MIN_US 500
#define SERVO_MAX_US 2500
#define SERVO_PERIOD_US 20000
#define SERVO_LEDC_TIMER LEDC_TIMER_1
#define SERVO_LEDC_CHANNEL LEDC_CHANNEL_1
#define SERVO_LEDC_RES LEDC_TIMER_14_BIT
#define SERVO_MAX_DUTY ((1 << 14) - 1)

esp_err_t servo_init(void)
{
    ledc_timer_config_t timer = {
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .timer_num = SERVO_LEDC_TIMER,
        .duty_resolution = SERVO_LEDC_RES,
        .freq_hz = 50,
        .clk_cfg = LEDC_AUTO_CLK,
    };
    ESP_ERROR_CHECK(ledc_timer_config(&timer));

    ledc_channel_config_t channel = {
        .gpio_num = SERVO_GPIO,
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .channel = SERVO_LEDC_CHANNEL,
        .intr_type = LEDC_INTR_DISABLE,
        .timer_sel = SERVO_LEDC_TIMER,
        .duty = 0,
        .hpoint = 0,
    };
    ESP_ERROR_CHECK(ledc_channel_config(&channel));
    return servo_set_angle(90);
}

esp_err_t servo_set_angle(int angle)
{
    if (angle < 0) {
        angle = 0;
    } else if (angle > 180) {
        angle = 180;
    }

    const int pulse_us = SERVO_MIN_US + ((SERVO_MAX_US - SERVO_MIN_US) * angle) / 180;
    const uint32_t duty = (uint32_t)(((uint64_t)pulse_us * SERVO_MAX_DUTY) / SERVO_PERIOD_US);
    esp_err_t err = ledc_set_duty(LEDC_LOW_SPEED_MODE, SERVO_LEDC_CHANNEL, duty);
    if (err == ESP_OK) {
        err = ledc_update_duty(LEDC_LOW_SPEED_MODE, SERVO_LEDC_CHANNEL);
    }
    if (err == ESP_OK) {
        app_state_lock();
        app_state_get()->servo_angle = angle;
        app_state_unlock();
    }
    return err;
}

