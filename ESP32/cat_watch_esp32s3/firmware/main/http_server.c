#include "http_server.h"

#include "app_state.h"
#include "camera_ov3660.h"
#include "servo.h"

#include "esp_http_server.h"
#include "esp_check.h"
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "nvs.h"
#include "nvs_flash.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern const uint8_t index_html_start[] asm("_binary_index_html_start");
extern const uint8_t index_html_end[] asm("_binary_index_html_end");
extern const uint8_t app_css_start[] asm("_binary_app_css_start");
extern const uint8_t app_css_end[] asm("_binary_app_css_end");
extern const uint8_t app_js_start[] asm("_binary_app_js_start");
extern const uint8_t app_js_end[] asm("_binary_app_js_end");

static const char *TAG = "http_server";
static const char *BOUNDARY = "123456789000000000000987654321";

static esp_err_t send_embedded(httpd_req_t *req, const uint8_t *start, const uint8_t *end, const char *type)
{
    httpd_resp_set_type(req, type);
    return httpd_resp_send(req, (const char *)start, end - start);
}

static esp_err_t index_handler(httpd_req_t *req)
{
    return send_embedded(req, index_html_start, index_html_end, "text/html; charset=utf-8");
}

static esp_err_t css_handler(httpd_req_t *req)
{
    return send_embedded(req, app_css_start, app_css_end, "text/css; charset=utf-8");
}

static esp_err_t js_handler(httpd_req_t *req)
{
    return send_embedded(req, app_js_start, app_js_end, "application/javascript; charset=utf-8");
}

static esp_err_t stream_handler(httpd_req_t *req)
{
    char part_buf[96];
    httpd_resp_set_type(req, "multipart/x-mixed-replace; boundary=123456789000000000000987654321");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");

    while (true) {
        camera_fb_t *fb = camera_ov3660_capture();
        if (!fb) {
            ESP_LOGW(TAG, "camera capture failed");
            return ESP_FAIL;
        }

        int header_len = snprintf(part_buf, sizeof(part_buf),
                                  "\r\n--%s\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n",
                                  BOUNDARY, (unsigned)fb->len);
        esp_err_t err = httpd_resp_send_chunk(req, part_buf, header_len);
        if (err == ESP_OK) {
            err = httpd_resp_send_chunk(req, (const char *)fb->buf, fb->len);
        }
        camera_ov3660_return(fb);

        if (err != ESP_OK) {
            break;
        }
    }
    return ESP_OK;
}

static void append_rect(char *buf, size_t len, const char *name, cat_rect_t r, bool last)
{
    snprintf(buf + strlen(buf), len - strlen(buf),
             "\"%s\":{\"x\":%d,\"y\":%d,\"w\":%d,\"h\":%d}%s",
             name, r.x, r.y, r.w, r.h, last ? "" : ",");
}

static esp_err_t status_handler(httpd_req_t *req)
{
    char body[1024];
    app_state_lock();
    app_state_t snapshot = *app_state_get();
    app_state_unlock();

    snprintf(body, sizeof(body),
             "{\"state\":\"%s\",\"state_since_ms\":%u,\"cat_visible\":%s,"
             "\"last_score\":%.3f,\"heap_free\":%u,\"psram_free\":%u,"
             "\"servo_angle\":%d,\"wifi_connected\":%s,\"regions\":{",
             cat_state_to_string(snapshot.behavior.state),
             (unsigned)snapshot.behavior.state_since_ms,
             snapshot.behavior.cat_visible ? "true" : "false",
             snapshot.behavior.last_score,
             (unsigned)esp_get_free_heap_size(),
             (unsigned)heap_caps_get_free_size(MALLOC_CAP_SPIRAM),
             snapshot.servo_angle,
             snapshot.wifi_connected ? "true" : "false");
    append_rect(body, sizeof(body), "bed", snapshot.behavior.regions.bed, false);
    append_rect(body, sizeof(body), "bowl", snapshot.behavior.regions.bowl, false);
    append_rect(body, sizeof(body), "left_exit", snapshot.behavior.regions.left_exit, false);
    append_rect(body, sizeof(body), "right_exit", snapshot.behavior.regions.right_exit, true);
    snprintf(body + strlen(body), sizeof(body) - strlen(body), "}}");

    httpd_resp_set_type(req, "application/json");
    return httpd_resp_sendstr(req, body);
}

static int parse_int_after(const char *body, const char *key, int fallback)
{
    const char *pos = strstr(body, key);
    if (!pos) {
        return fallback;
    }
    pos += strlen(key);
    return atoi(pos);
}

static cat_rect_t parse_region(const char *body, const char *name, cat_rect_t fallback)
{
    const char *pos = strstr(body, name);
    if (!pos) {
        return fallback;
    }
    cat_rect_t r = fallback;
    r.x = parse_int_after(pos, "\"x\":", r.x);
    r.y = parse_int_after(pos, "\"y\":", r.y);
    r.w = parse_int_after(pos, "\"w\":", r.w);
    r.h = parse_int_after(pos, "\"h\":", r.h);
    return r;
}

static void save_regions_to_nvs(const cat_regions_t *regions)
{
    nvs_handle_t nvs;
    if (nvs_open("catwatch", NVS_READWRITE, &nvs) == ESP_OK) {
        nvs_set_blob(nvs, "regions", regions, sizeof(*regions));
        nvs_commit(nvs);
        nvs_close(nvs);
    }
}

static esp_err_t regions_handler(httpd_req_t *req)
{
    char body[768] = {0};
    int received = httpd_req_recv(req, body, sizeof(body) - 1);
    if (received <= 0) {
        return ESP_FAIL;
    }

    app_state_lock();
    cat_regions_t regions = app_state_get()->behavior.regions;
    regions.bed = parse_region(body, "\"bed\"", regions.bed);
    regions.bowl = parse_region(body, "\"bowl\"", regions.bowl);
    regions.left_exit = parse_region(body, "\"left_exit\"", regions.left_exit);
    regions.right_exit = parse_region(body, "\"right_exit\"", regions.right_exit);
    behavior_engine_set_regions(&app_state_get()->behavior, &regions);
    app_state_unlock();

    save_regions_to_nvs(&regions);
    httpd_resp_set_type(req, "application/json");
    return httpd_resp_sendstr(req, "{\"ok\":true}");
}

static esp_err_t servo_handler(httpd_req_t *req)
{
    char body[96] = {0};
    int received = httpd_req_recv(req, body, sizeof(body) - 1);
    if (received <= 0) {
        return ESP_FAIL;
    }
    int angle = parse_int_after(body, "\"angle\":", 90);
    esp_err_t err = servo_set_angle(angle);
    if (err != ESP_OK) {
        return err;
    }
    httpd_resp_set_type(req, "application/json");
    return httpd_resp_sendstr(req, "{\"ok\":true}");
}

static esp_err_t events_handler(httpd_req_t *req)
{
    behavior_event_t events[BEHAVIOR_EVENT_CAPACITY];
    app_state_lock();
    uint8_t count = behavior_engine_copy_events(&app_state_get()->behavior, events, BEHAVIOR_EVENT_CAPACITY);
    app_state_unlock();

    char body[1536];
    snprintf(body, sizeof(body), "[");
    for (uint8_t i = 0; i < count; ++i) {
        snprintf(body + strlen(body), sizeof(body) - strlen(body),
                 "%s{\"state\":\"%s\",\"at_ms\":%u,\"duration_ms\":%u,\"score\":%.3f}",
                 i == 0 ? "" : ",",
                 cat_state_to_string(events[i].state),
                 (unsigned)events[i].at_ms,
                 (unsigned)events[i].duration_ms,
                 events[i].score);
    }
    snprintf(body + strlen(body), sizeof(body) - strlen(body), "]");
    httpd_resp_set_type(req, "application/json");
    return httpd_resp_sendstr(req, body);
}

esp_err_t http_server_start(void)
{
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.stack_size = 8192;
    config.uri_match_fn = httpd_uri_match_wildcard;

    httpd_handle_t server = NULL;
    ESP_RETURN_ON_ERROR(httpd_start(&server, &config), TAG, "httpd_start failed");

    const httpd_uri_t routes[] = {
        {.uri = "/", .method = HTTP_GET, .handler = index_handler},
        {.uri = "/app.css", .method = HTTP_GET, .handler = css_handler},
        {.uri = "/app.js", .method = HTTP_GET, .handler = js_handler},
        {.uri = "/stream", .method = HTTP_GET, .handler = stream_handler},
        {.uri = "/api/status", .method = HTTP_GET, .handler = status_handler},
        {.uri = "/api/events", .method = HTTP_GET, .handler = events_handler},
        {.uri = "/api/regions", .method = HTTP_POST, .handler = regions_handler},
        {.uri = "/api/servo", .method = HTTP_POST, .handler = servo_handler},
    };

    for (size_t i = 0; i < sizeof(routes) / sizeof(routes[0]); ++i) {
        ESP_ERROR_CHECK(httpd_register_uri_handler(server, &routes[i]));
    }
    ESP_LOGI(TAG, "HTTP server started");
    return ESP_OK;
}
