#include "behavior_engine.h"

#include <stddef.h>
#include <string.h>

static bool rect_valid(cat_rect_t r)
{
    return r.w > 0 && r.h > 0;
}

static bool point_in_rect(int x, int y, cat_rect_t r)
{
    return rect_valid(r) && x >= r.x && y >= r.y && x < (r.x + r.w) && y < (r.y + r.h);
}

static int rect_center_x(cat_rect_t r)
{
    return r.x + (r.w / 2);
}

static int rect_center_y(cat_rect_t r)
{
    return r.y + (r.h / 2);
}

static void push_event(behavior_engine_t *engine, uint32_t now_ms, cat_state_t state, uint32_t duration_ms, float score)
{
    if (engine->event_count > 0) {
        uint8_t last_idx = (uint8_t)((engine->event_head + BEHAVIOR_EVENT_CAPACITY - 1U) % BEHAVIOR_EVENT_CAPACITY);
        behavior_event_t *last = &engine->events[last_idx];
        if (last->state == state && (now_ms - last->at_ms) < 1000U) {
            last->duration_ms = duration_ms;
            last->score = score;
            return;
        }
    }

    behavior_event_t *event = &engine->events[engine->event_head];
    event->state = state;
    event->at_ms = now_ms;
    event->duration_ms = duration_ms;
    event->score = score;

    engine->event_head = (uint8_t)((engine->event_head + 1U) % BEHAVIOR_EVENT_CAPACITY);
    if (engine->event_count < BEHAVIOR_EVENT_CAPACITY) {
        engine->event_count++;
    }
}

static void set_state(behavior_engine_t *engine, uint32_t now_ms, cat_state_t state, uint32_t duration_ms)
{
    if (engine->state == state) {
        return;
    }

    engine->state = state;
    engine->state_since_ms = now_ms;
    push_event(engine, now_ms, state, duration_ms, engine->last_score);
}

void behavior_engine_init(behavior_engine_t *engine, int frame_w, int frame_h)
{
    memset(engine, 0, sizeof(*engine));
    engine->frame_w = frame_w;
    engine->frame_h = frame_h;
    engine->state = CAT_STATE_UNKNOWN;
    engine->config.rest_ms = 10U * 60U * 1000U;
    engine->config.eat_ms = 60U * 1000U;
    engine->config.lost_ms = 5000U;
    engine->config.exit_lost_ms = 2500U;
    engine->config.min_score = 0.45f;

    engine->regions.bed = (cat_rect_t){frame_w / 8, frame_h / 4, frame_w / 3, frame_h / 3};
    engine->regions.bowl = (cat_rect_t){(frame_w * 5) / 8, (frame_h * 2) / 3, frame_w / 4, frame_h / 4};
    engine->regions.left_exit = (cat_rect_t){0, 0, frame_w / 8, frame_h};
    engine->regions.right_exit = (cat_rect_t){frame_w - (frame_w / 8), 0, frame_w / 8, frame_h};
}

void behavior_engine_set_regions(behavior_engine_t *engine, const cat_regions_t *regions)
{
    if (regions) {
        engine->regions = *regions;
    }
}

void behavior_engine_set_config(behavior_engine_t *engine, const behavior_config_t *config)
{
    if (config) {
        engine->config = *config;
    }
}

void behavior_engine_update(behavior_engine_t *engine, uint32_t now_ms, const cat_detection_t *detection)
{
    const bool visible = detection && detection->found && detection->score >= engine->config.min_score;

    if (!visible) {
        engine->cat_visible = false;
        engine->bed_enter_ms = 0;
        engine->bowl_enter_ms = 0;

        if (engine->last_seen_ms != 0U && engine->pending_exit != CAT_STATE_UNKNOWN &&
            (now_ms - engine->last_seen_ms) >= engine->config.exit_lost_ms) {
            set_state(engine, now_ms, engine->pending_exit, now_ms - engine->edge_enter_ms);
            engine->pending_exit = CAT_STATE_UNKNOWN;
            return;
        }

        if (engine->last_seen_ms != 0U && (now_ms - engine->last_seen_ms) >= engine->config.lost_ms) {
            set_state(engine, now_ms, CAT_STATE_AWAY, now_ms - engine->last_seen_ms);
        }
        return;
    }

    engine->cat_visible = true;
    engine->last_seen_ms = now_ms;
    engine->last_score = detection->score;
    engine->last_box = detection->box;

    const int cx = rect_center_x(detection->box);
    const int cy = rect_center_y(detection->box);
    const bool in_bed = point_in_rect(cx, cy, engine->regions.bed);
    const bool in_bowl = point_in_rect(cx, cy, engine->regions.bowl);
    const bool in_left = point_in_rect(cx, cy, engine->regions.left_exit);
    const bool in_right = point_in_rect(cx, cy, engine->regions.right_exit);

    if (in_left || in_right) {
        cat_state_t exit_state = in_left ? CAT_STATE_LEFT_EXIT : CAT_STATE_RIGHT_EXIT;
        if (engine->pending_exit != exit_state) {
            engine->pending_exit = exit_state;
            engine->edge_enter_ms = now_ms;
        }
    } else {
        engine->pending_exit = CAT_STATE_UNKNOWN;
        engine->edge_enter_ms = 0;
    }

    if (in_bed) {
        if (engine->bed_enter_ms == 0U) {
            engine->bed_enter_ms = now_ms;
        }
        if ((now_ms - engine->bed_enter_ms) >= engine->config.rest_ms) {
            set_state(engine, now_ms, CAT_STATE_RESTING, now_ms - engine->bed_enter_ms);
            return;
        }
    } else {
        engine->bed_enter_ms = 0;
    }

    if (in_bowl) {
        if (engine->bowl_enter_ms == 0U) {
            engine->bowl_enter_ms = now_ms;
        }
        if ((now_ms - engine->bowl_enter_ms) >= engine->config.eat_ms) {
            set_state(engine, now_ms, CAT_STATE_EATING, now_ms - engine->bowl_enter_ms);
            return;
        }
    } else {
        engine->bowl_enter_ms = 0;
    }

    set_state(engine, now_ms, CAT_STATE_VISIBLE, 0);
}

const char *cat_state_to_string(cat_state_t state)
{
    switch (state) {
    case CAT_STATE_VISIBLE:
        return "visible";
    case CAT_STATE_RESTING:
        return "resting";
    case CAT_STATE_EATING:
        return "eating";
    case CAT_STATE_AWAY:
        return "away";
    case CAT_STATE_LEFT_EXIT:
        return "left_exit";
    case CAT_STATE_RIGHT_EXIT:
        return "right_exit";
    case CAT_STATE_UNKNOWN:
    default:
        return "unknown";
    }
}

uint8_t behavior_engine_copy_events(const behavior_engine_t *engine, behavior_event_t *out, uint8_t max_events)
{
    const uint8_t count = engine->event_count < max_events ? engine->event_count : max_events;
    const uint8_t start = (uint8_t)((engine->event_head + BEHAVIOR_EVENT_CAPACITY - engine->event_count) %
                                    BEHAVIOR_EVENT_CAPACITY);

    for (uint8_t i = 0; i < count; ++i) {
        out[i] = engine->events[(start + i) % BEHAVIOR_EVENT_CAPACITY];
    }
    return count;
}
