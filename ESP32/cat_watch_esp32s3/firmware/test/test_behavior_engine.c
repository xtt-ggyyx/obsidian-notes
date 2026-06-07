#include "behavior_engine.h"

#include <assert.h>
#include <stdio.h>

static cat_detection_t det(int x, int y, float score)
{
    return (cat_detection_t){
        .found = true,
        .score = score,
        .box = {x, y, 30, 30},
    };
}

static void test_resting(void)
{
    behavior_engine_t engine;
    behavior_engine_init(&engine, 320, 240);
    behavior_config_t cfg = engine.config;
    cfg.rest_ms = 3000;
    behavior_engine_set_config(&engine, &cfg);
    cat_detection_t d = det(50, 70, 0.9f);

    behavior_engine_update(&engine, 1000, &d);
    behavior_engine_update(&engine, 4500, &d);

    assert(engine.state == CAT_STATE_RESTING);
}

static void test_eating(void)
{
    behavior_engine_t engine;
    behavior_engine_init(&engine, 320, 240);
    behavior_config_t cfg = engine.config;
    cfg.eat_ms = 2000;
    behavior_engine_set_config(&engine, &cfg);
    cat_detection_t d = det(225, 165, 0.8f);

    behavior_engine_update(&engine, 100, &d);
    behavior_engine_update(&engine, 2500, &d);

    assert(engine.state == CAT_STATE_EATING);
}

static void test_left_exit(void)
{
    behavior_engine_t engine;
    behavior_engine_init(&engine, 320, 240);
    cat_detection_t left = det(1, 90, 0.95f);
    cat_detection_t none = {.found = false};

    behavior_engine_update(&engine, 1000, &left);
    behavior_engine_update(&engine, 3600, &none);

    assert(engine.state == CAT_STATE_LEFT_EXIT);
}

static void test_right_exit(void)
{
    behavior_engine_t engine;
    behavior_engine_init(&engine, 320, 240);
    cat_detection_t right = det(292, 90, 0.95f);
    cat_detection_t none = {.found = false};

    behavior_engine_update(&engine, 1000, &right);
    behavior_engine_update(&engine, 3600, &none);

    assert(engine.state == CAT_STATE_RIGHT_EXIT);
}

static void test_away_without_exit(void)
{
    behavior_engine_t engine;
    behavior_engine_init(&engine, 320, 240);
    behavior_config_t cfg = engine.config;
    cfg.lost_ms = 2000;
    behavior_engine_set_config(&engine, &cfg);
    cat_detection_t mid = det(140, 90, 0.8f);
    cat_detection_t none = {.found = false};

    behavior_engine_update(&engine, 1000, &mid);
    behavior_engine_update(&engine, 3500, &none);

    assert(engine.state == CAT_STATE_AWAY);
}

int main(void)
{
    test_resting();
    test_eating();
    test_left_exit();
    test_right_exit();
    test_away_without_exit();
    puts("behavior_engine tests passed");
    return 0;
}
