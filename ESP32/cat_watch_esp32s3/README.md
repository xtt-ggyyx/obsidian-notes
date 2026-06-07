# ESP32-S3 + OV3660 猫咪看护项目

这是一个自研 PCB 方向的 ESP32-S3 + OV3660 猫咪看护项目骨架。

当前工程已经包含：

- ESP-IDF 固件目录结构。
- OV3660 摄像头初始化代码。
- Wi-Fi 联网代码。
- 局域网手机网页。
- MJPEG 实时视频流接口。
- 区域绘制、保存和读取接口。
- 猫咪行为判断核心逻辑。
- 舵机 PWM 控制代码。
- 自研 PCB 的引脚、电源、BOM 和调试检查表。

当前猫咪检测模型还没有真正接入。
固件里先用 `cat_detector_stub.c` 做占位，这样可以先验证摄像头、Wi-Fi、网页、区域配置和行为判断逻辑。
后续接入乐鑫 ESP-Detection 猫检测模型时，只需要替换检测适配层。

## 目录说明

- `firmware/`：ESP-IDF 固件工程。
- `firmware/main/web/`：手机网页界面。
- `firmware/test/`：电脑端行为判断测试。
- `hardware/`：PCB 设计资料。
- `docs/`：项目计划、接口说明、模型接入说明。

## Obsidian 常用入口

- [[项目进度总表]]
- [[docs/索引]]
- [[docs/问题记录]]
- [[docs/项目总体计划]]
- [[docs/项目优化建议]]
- [[hardware/3D外壳打印和装配说明]]
- [[docs/换电脑继续项目指南]]

## 固件编译

先安装 ESP-IDF，然后进入 `firmware/`：

```powershell
idf.py set-target esp32s3
idf.py menuconfig
idf.py build
idf.py flash monitor
```

需要在 `menuconfig` 里确认：

- 开启 PSRAM。
- 填写 Wi-Fi 名称和密码。
- 摄像头引脚和你最终 PCB 原理图一致。

## 电脑端行为逻辑测试

不需要 ESP-IDF，直接用 GCC 测试行为判断：

```powershell
cd firmware
gcc -std=c11 -Wall -Wextra -I main/include test/test_behavior_engine.c main/behavior_engine.c -o test_behavior_engine.exe
.\test_behavior_engine.exe
```

测试通过时会输出：

```text
behavior_engine tests passed
```
