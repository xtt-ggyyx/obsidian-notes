idf_component_register(
    SRCS
        "app_main.c"
        "app_state.c"
        "behavior_engine.c"
        "camera_ov3660.c"
        "cat_detector_stub.c"
        "http_server.c"
        "servo.c"
        "wifi_station.c"
    INCLUDE_DIRS
        "include"
    EMBED_FILES
        "web/index.html"
        "web/app.css"
        "web/app.js"
)

