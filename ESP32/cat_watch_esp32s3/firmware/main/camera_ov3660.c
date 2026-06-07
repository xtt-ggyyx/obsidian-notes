#include "camera_ov3660.h"

#include "esp_log.h"
#include "sdkconfig.h"

static const char *TAG = "camera_ov3660";

// Must match hardware/pin_map.md.
#define PIN_D0 12
#define PIN_D1 11
#define PIN_D2 10
#define PIN_D3 9
#define PIN_D4 8
#define PIN_D5 18
#define PIN_D6 17
#define PIN_D7 16
#define PIN_XCLK 15
#define PIN_PCLK 13
#define PIN_VSYNC 6
#define PIN_HREF 7
#define PIN_SIOD 4
#define PIN_SIOC 5
#define PIN_PWDN 21
#define PIN_RESET 14

esp_err_t camera_ov3660_init(void)
{
    camera_config_t config = {
        .pin_pwdn = PIN_PWDN,
        .pin_reset = PIN_RESET,
        .pin_xclk = PIN_XCLK,
        .pin_sccb_sda = PIN_SIOD,
        .pin_sccb_scl = PIN_SIOC,
        .pin_d7 = PIN_D7,
        .pin_d6 = PIN_D6,
        .pin_d5 = PIN_D5,
        .pin_d4 = PIN_D4,
        .pin_d3 = PIN_D3,
        .pin_d2 = PIN_D2,
        .pin_d1 = PIN_D1,
        .pin_d0 = PIN_D0,
        .pin_vsync = PIN_VSYNC,
        .pin_href = PIN_HREF,
        .pin_pclk = PIN_PCLK,
        .xclk_freq_hz = 20000000,
        .ledc_timer = LEDC_TIMER_0,
        .ledc_channel = LEDC_CHANNEL_0,
        .pixel_format = PIXFORMAT_JPEG,
        .frame_size = FRAMESIZE_QVGA,
        .jpeg_quality = 12,
        .fb_count = 2,
        .grab_mode = CAMERA_GRAB_LATEST,
        .fb_location = CAMERA_FB_IN_PSRAM,
    };

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_camera_init failed: %s", esp_err_to_name(err));
        return err;
    }

    sensor_t *sensor = esp_camera_sensor_get();
    if (sensor) {
        ESP_LOGI(TAG, "camera pid=0x%04x", sensor->id.PID);
        sensor->set_framesize(sensor, FRAMESIZE_QVGA);
        sensor->set_quality(sensor, 12);
    }

    return ESP_OK;
}

camera_fb_t *camera_ov3660_capture(void)
{
    return esp_camera_fb_get();
}

void camera_ov3660_return(camera_fb_t *fb)
{
    if (fb) {
        esp_camera_fb_return(fb);
    }
}

