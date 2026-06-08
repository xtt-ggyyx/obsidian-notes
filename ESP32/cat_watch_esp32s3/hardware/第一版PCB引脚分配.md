# 第一版 PCB 引脚分配

这是 ESP32-S3-WROOM-1 / WROOM-1U + OV3660 的第一版建议引脚。
画原理图前必须再检查一次 ESP32-S3 的启动绑定位、PSRAM 占用引脚、USB 引脚和实际 PCB 走线。

## ESP32-S3 模组选型

优先选择带 PSRAM 的模组：

- 推荐：`ESP32-S3-WROOM-1-N16R8`
- 备选：`ESP32-S3-WROOM-1U-N16R8`

如果外壳会遮挡 PCB 天线，优先用 `WROOM-1U` 外接天线版本。

## 需要避开的引脚

- `GPIO19`：USB D-
- `GPIO20`：USB D+
- `GPIO0`：下载启动 BOOT 引脚，需要保留按键和测试点。
- `GPIO45`、`GPIO46`、`GPIO3`：启动绑定位，不建议随便接摄像头时钟或控制信号。
- `GPIO35`、`GPIO36`、`GPIO37`：R8 模组上可能被 OSPI PSRAM 占用，第一版建议避开。

## OV3660 摄像头引脚

第一版使用 8 位 DVP 输出，只接 `D9..D2`，不接 `D1/D0`。

| OV3660 信号 | ESP32-S3 GPIO | 说明          |
| --------- | ------------: | ----------- |
| D9        |        GPIO16 | 数据 bit7     |
| D8        |        GPIO17 | 数据 bit6     |
| D7        |        GPIO18 | 数据 bit5     |
| D6        |         GPIO8 | 数据 bit4     |
| D5        |         GPIO9 | 数据 bit3     |
| D4        |        GPIO10 | 数据 bit2     |
| D3        |        GPIO11 | 数据 bit1     |
| D2        |        GPIO12 | 数据 bit0     |
| PCLK      |        GPIO13 | 像素时钟        |
| VSYNC     |         GPIO6 | 场同步         |
| HREF      |         GPIO7 | 行同步         |
| XVCLK     |        GPIO15 | 摄像头主时钟      |
| SIOC      |         GPIO5 | SCCB 时钟     |
| SIOD      |         GPIO4 | SCCB 数据     |
| RESETB    |        GPIO14 | 摄像头复位，低有效   |
| PWDN      |        GPIO21 | 摄像头掉电控制，高有效 |

## 舵机接口

| 信号 | ESP32-S3 GPIO | 说明 |
| --- | ---: | --- |
| SERVO_PWM | GPIO47 | LEDC PWM，50 Hz |

舵机电源必须接独立的 `5V_SERVO`，不要从 ESP32-S3 的 3.3V 取电。

## 音频预留接口

第一版可以只预留焊盘，不焊元件。

| 功能 | GPIO |
| --- | ---: |
| I2S BCLK | GPIO38 |
| I2S WS | GPIO39 |
| I2S 麦克风输入 | GPIO40 |
| I2S 功放输出 | GPIO41 |

