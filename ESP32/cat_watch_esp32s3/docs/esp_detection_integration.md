# ESP-Detection 猫检测模型接入说明

当前固件使用的是 `cat_detector_stub.c` 占位检测器。
这个文件不会真的识别猫，只是让摄像头、网页、区域配置和行为判断可以先跑起来。

后续接入 ESP-Detection 时，只需要保持下面两个函数接口不变：

```c
esp_err_t cat_detector_init(void);
esp_err_t cat_detector_detect(camera_fb_t *fb, cat_detection_t *out_detection);
```

## 检测输出要求

`cat_detector_detect()` 需要填充：

- `found`：是否检测到猫。
- `score`：置信度，范围 `0.0..1.0`。
- `box`：猫咪检测框，坐标要换算到网页使用的逻辑画面大小，当前默认是 `320 x 240`。

## 推荐接入步骤

1. 先用当前占位检测器验证摄像头和网页。
2. 按乐鑫官方示例加入 ESP-Detection / ESP-DL 依赖。
3. 把摄像头图像转换成猫检测模型需要的输入格式。
4. 运行模型，拿到猫咪检测框。
5. 把模型输出坐标缩放回 `320 x 240`。
6. 从 `0.45` 开始调整置信度阈值。
7. 串口打印每次推理耗时、剩余 heap 和剩余 PSRAM。

## 注意事项

- 先用低分辨率输入，不要一开始追求高清。
- 视频流先保持 QVGA/JPEG，等推理稳定后再调。
- 如果视频和模型同时运行导致卡顿，优先降低检测频率。
- 不要在 PCB 调试阶段同时调模型，否则问题来源会混在一起。

