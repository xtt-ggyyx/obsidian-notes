# HTTP 接口说明

第一版接口只面向局域网使用，默认没有登录认证。
如果以后要暴露到外网，必须增加鉴权和 HTTPS/反向代理保护。

## `GET /`

打开手机网页界面。

## `GET /stream`

返回 MJPEG 实时视频流。

手机网页中的画面就是通过这个接口显示的。

## `GET /api/status`

返回设备当前状态。

示例：

```json
{
  "state": "resting",
  "state_since_ms": 123000,
  "cat_visible": true,
  "last_score": 0.73,
  "heap_free": 130000,
  "psram_free": 4200000,
  "servo_angle": 90,
  "regions": {
    "bed": {"x": 40, "y": 60, "w": 120, "h": 100},
    "bowl": {"x": 220, "y": 170, "w": 80, "h": 60},
    "left_exit": {"x": 0, "y": 0, "w": 35, "h": 240},
    "right_exit": {"x": 285, "y": 0, "w": 35, "h": 240}
  }
}
```

字段含义：

- `state`：当前行为状态。
- `state_since_ms`：当前状态开始时间，单位毫秒。
- `cat_visible`：当前是否检测到猫。
- `last_score`：最近一次检测置信度。
- `heap_free`：剩余堆内存。
- `psram_free`：剩余 PSRAM。
- `servo_angle`：舵机角度。
- `regions`：用户设置的画面区域。

## `POST /api/regions`

保存区域配置。

请求体示例：

```json
{
  "bed": {"x": 40, "y": 60, "w": 120, "h": 100},
  "bowl": {"x": 220, "y": 170, "w": 80, "h": 60},
  "left_exit": {"x": 0, "y": 0, "w": 35, "h": 240},
  "right_exit": {"x": 285, "y": 0, "w": 35, "h": 240}
}
```

坐标基于固件中配置的逻辑画面大小，当前默认是 `320 x 240`。

## `GET /api/events`

返回最近的行为事件列表。

## `POST /api/servo`

设置舵机角度。

请求体示例：

```json
{"angle": 90}
```

角度范围是 `0..180`。

