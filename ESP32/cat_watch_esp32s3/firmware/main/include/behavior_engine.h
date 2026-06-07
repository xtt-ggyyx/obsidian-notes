#ifndef BEHAVIOR_ENGINE_H
#define BEHAVIOR_ENGINE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BEHAVIOR_EVENT_CAPACITY 16

typedef enum {
    CAT_STATE_UNKNOWN = 0,
    CAT_STATE_VISIBLE,
    CAT_STATE_RESTING,
    CAT_STATE_EATING,
    CAT_STATE_AWAY,
    CAT_STATE_LEFT_EXIT,
    CAT_STATE_RIGHT_EXIT,
} cat_state_t;

typedef struct {
    int x;
    int y;
    int w;
    int h;
} cat_rect_t;

typedef struct {
    bool found;
    float score;
    cat_rect_t box;
} cat_detection_t;

typedef struct {
    cat_rect_t bed;
    cat_rect_t bowl;
    cat_rect_t left_exit;
    cat_rect_t right_exit;
} cat_regions_t;

typedef struct {
    uint32_t rest_ms;
    uint32_t eat_ms;
    uint32_t lost_ms;
    uint32_t exit_lost_ms;
    float min_score;
} behavior_config_t;

typedef struct {
    cat_state_t state;
    uint32_t at_ms;
    uint32_t duration_ms;
    float score;
} behavior_event_t;

typedef struct {
    behavior_config_t config;
    cat_regions_t regions;
    int frame_w;
    int frame_h;
    cat_state_t state;
    uint32_t state_since_ms;
    bool cat_visible;
    float last_score;
    cat_rect_t last_box;
    uint32_t last_seen_ms;
    uint32_t bed_enter_ms;
    uint32_t bowl_enter_ms;
    uint32_t edge_enter_ms;
    cat_state_t pending_exit;
    behavior_event_t events[BEHAVIOR_EVENT_CAPACITY];
    uint8_t event_count;
    uint8_t event_head;
} behavior_engine_t;

void behavior_engine_init(behavior_engine_t *engine, int frame_w, int frame_h);
void behavior_engine_set_regions(behavior_engine_t *engine, const cat_regions_t *regions);
void behavior_engine_set_config(behavior_engine_t *engine, const behavior_config_t *config);
void behavior_engine_update(behavior_engine_t *engine, uint32_t now_ms, const cat_detection_t *detection);
const char *cat_state_to_string(cat_state_t state);
uint8_t behavior_engine_copy_events(const behavior_engine_t *engine, behavior_event_t *out, uint8_t max_events);

#ifdef __cplusplus
}
#endif

#endif
