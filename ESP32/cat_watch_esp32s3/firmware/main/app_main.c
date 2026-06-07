#include "app_state.h"
#include "camera_ov3660.h"
#include "cat_detector.h"
#include "http_server.h"
#include "servo.h"
#include "wifi_station.h"

#include "esp_log.h"
#include "esp_timer.h"
#include "nvs.h"
#include "nvs_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "cat_watch";

static void load_regions_from_nvs(void)
{
    nvs_handle_t nvs;
    if (nvs_open("catwatch", NVS_READONLY, &nvs) != ESP_OK) {
        return;
    }
    cat_regions_t regions;
    size_t len = sizeof(regions);
    if (nvs_get_blob(nvs, "regions", &regions, &len) == ESP_OK && len == sizeof(regions)) {
        app_state_lock();
        behavior_engine_set_regions(&app_state_get()->behavior, &regions);
        app_state_unlock();
    }
    nvs_close(nvs);
}

static void inference_task(void *arg)
{
    (void)arg;
    while (true) {
        camera_fb_t *fb = camera_ov3660_capture();
        cat_detection_t detection = {0};
        if (fb) {
            cat_detector_detect(fb, &detection);
            camera_ov3660_return(fb);
        }

        uint32_t now_ms = (uint32_t)(esp_timer_get_time() / 1000ULL);
        app_state_lock();
        behavior_engine_update(&app_state_get()->behavior, now_ms, &detection);
        app_state_get()->last_frame_ms = now_ms;
        app_state_unlock();

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

void app_main(void)
{
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK(err);

    app_state_init();
    load_regions_from_nvs();

    ESP_ERROR_CHECK(servo_init());
    ESP_ERROR_CHECK(wifi_station_start());
    ESP_ERROR_CHECK(camera_ov3660_init());
    ESP_ERROR_CHECK(cat_detector_init());
    ESP_ERROR_CHECK(http_server_start());

    xTaskCreatePinnedToCore(inference_task, "inference", 8192, NULL, 5, NULL, 1);
    ESP_LOGI(TAG, "cat watch started");
}

