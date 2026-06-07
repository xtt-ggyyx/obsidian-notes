# PCB 学习资料与当前原理图初步检查

记录日期：2026-06-07

当前 PCB 工程路径：

```text
F:\EDA\LCEDA-Pro1\online-projects-backup\xxx1\xxx1_2026-06-07-22-20-13
```

工程文件：

```text
project2.json
xxx1.epru
IMAGE/591bf92b3f1f3d56.webp
```

## 一、建议优先看的官方资料

### 1. ESP32-S3 硬件设计指南

链接：

https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32s3/index.html

用途：

- ESP32-S3 原理图检查。
- 电源设计。
- CHIP_PU / EN 复位。
- Strapping 启动引脚。
- USB。
- PCB layout。
- 天线禁布。

这是当前最重要的资料，画 PCB 前必须反复看。

### 2. ESP32-S3 Schematic Checklist

链接：

https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32s3/schematic-checklist.html

重点记录：

- ESP32-S3 单电源系统推荐 3.3V，输出电流不低于 500mA。
- 电源入口建议加 ESD 保护和至少 10uF 电容。
- `CHIP_PU` 不能悬空。
- 推荐 `CHIP_PU` 使用 RC 延时，常见值是 `10kΩ + 1uF`。
- GPIO19 / GPIO20 可作为 USB D- / D+。
- USB D+/D- 建议预留 22Ω 或 33Ω 串联电阻和到地电容焊盘，靠近芯片放置。

### 3. ESP32-S3 PCB Layout Design

链接：

https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32s3/pcb-layout-design.html

重点记录：

- ESP32-S3 模组天线最好伸出 PCB 边缘。
- 如果天线不能伸出板外，天线周围至少留 `15mm` 禁布区。
- 天线区域所有层都不要铺铜、走线或放器件。
- USB 差分线需要平行、等长、阻抗约 `90Ω ±10%`。
- USB 差分线下方要有连续参考地。
- USB 线尽量少过孔，如果必须过孔，要加回流地过孔。

### 4. ESP32-S3-WROOM-1 / WROOM-1U 数据手册

链接：

https://www.espressif.com/sites/default/files/documentation/esp32-s3-wroom-1_wroom-1u_datasheet_en.pdf

重点记录：

- `ESP32-S3-WROOM-1` 是 PCB 天线版本。
- `ESP32-S3-WROOM-1U` 是外接天线版本。
- 项目需要摄像头和模型，必须选带 PSRAM 的型号。
- 推荐 `N16R8` 或至少 `N8R8`。
- 模组供电范围是 `3.0V ~ 3.6V`。

### 5. esp32-camera 官方组件

链接：

https://components.espressif.com/components/espressif/esp32-camera

重点记录：

- 官方支持 ESP32-S3。
- 官方支持 OV3660。
- OV3660 最大分辨率 `2048 x 1536`。
- 除 CIF 或更低分辨率 JPEG 外，基本需要 PSRAM。
- YUV/RGB 对芯片压力很大，尤其 Wi-Fi 同时开启时更明显。
- 如果需要 RGB，推荐先采集 JPEG，再用 `fmt2rgb888` 等方式转换。

### 6. USB Type-C CC 电阻资料

链接：

https://onlinedocs.microchip.com/oxy/GUID-DAF68E19-EB64-4E93-83DB-9E883647B776-en-US-1/GUID-02E3AD6F-2676-4B83-9D2E-31D93E162FA3.html

重点记录：

- Type-C 的 CC 线用于检测设备连接和插头方向。
- 设备端通常在 CC1 和 CC2 上各接一个 `5.1kΩ` 到 GND。
- 如果 CC 配置错误，主机可能检测不到设备，也可能不给电。

## 二、当前原理图初步观察

根据 `IMAGE/591bf92b3f1f3d56.webp` 和 `.epru` 文本搜索，当前已经画了这些部分：

- Type-C 接口。
- CC1 / CC2 各接 `5.1kΩ` 到 GND。
- 5V 输入。
- 3.3V LDO，型号类似 `SGM2212-3.3`。
- 3.3V 电源指示 LED。
- ESP32-S3-WROOM-1 模组。
- `CHIP_PU` 上拉和复位电路。
- IO0 BOOT 按键。
- 摄像头接口，图中标为 `CAM3660`，工程里也搜到 `CAM2640.1`。
- 摄像头信号包括 `SIOC`、`SIOD`、`PCLK`、`VSYNC`、`HREF`、`PWDN`、`RESET`。

整体方向是对的，但现在还不能直接打板，需要先逐项复查。

## 三、当前原理图最需要优先检查的问题

### 1. 摄像头符号和 OV3660 引脚必须重新核对

当前截图里摄像头写的是 `CAM3660`，但 `.epru` 中能搜到 `CAM2640.1`。

这说明你可能用了 OV2640 摄像头接口符号改名，或者符号库内部名字还叫 CAM2640。

必须检查：

- 这个 24pin 摄像头座的引脚顺序是否真的对应 OV3660 数据手册。
- `AVDD` 是否接 2.8V。
- `DOVDD` 是否接 1.8V 或你设计的 I/O 电平。
- `DVDD` 是否按 OV3660 手册处理。
- `PWDN` 不能悬空。
- `RESET` 要由 ESP32-S3 控制。
- `D9..D2` 是否作为 8-bit 数据接到 ESP32-S3。
- `D1/D0` 是否明确不接。

如果摄像头引脚顺序错了，后面软件完全救不回来。

### 2. 当前 2.8V 和 1.8V 电源还需要确认来源

截图中摄像头附近有 `2.8V` 和 `1.8V` 网络名，但整张图里只明显看到一个 3.3V LDO。

必须确认：

- 是否已经画了 2.8V LDO。
- 是否已经画了 1.8V LDO。
- 2.8V 和 1.8V 是否有去耦电容。
- 这两个电源是否上电顺序满足 OV3660 手册。

如果还没画，下一步必须补。

### 3. USB D+ / D- 两面引脚要合并

Type-C 口有正反插两组 USB2.0 数据脚。

需要确认：

- A6 / B6 两个 D+ 是否合并。
- A7 / B7 两个 D- 是否合并。
- 合并后 D+ 接 ESP32-S3 `GPIO20`。
- 合并后 D- 接 ESP32-S3 `GPIO19`。
- D+ / D- 上是否预留 22Ω 或 33Ω 串联电阻。
- 串联电阻尽量靠近 ESP32-S3。

截图中可以看到 `DP1/DN1/DP2/DN2`，但需要确认最终是否全部正确连到 IO20/IO19。

### 4. ESP32-S3 模组所有 GND 和 EPAD 要接地

截图中模组符号有多个 GND。

必须确认：

- 所有 GND 引脚都接到 GND。
- EPAD 接到 GND。
- 模组下方和周围有足够地过孔。
- 电源去耦靠近 3V3 引脚。

不要只接一个 GND。

### 5. CHIP_PU 电路方向基本对，但要确认参数

当前看到：

- `CHIP_PU` 通过 `10kΩ` 上拉到 `ESP_3V3`。
- 有 `1uF` 到 GND。
- 有复位按键到 GND。

这符合乐鑫推荐方向。

需要确认：

- 电容是 1uF，不是 100nF。
- 复位按键按下时确实拉低 `CHIP_PU`。
- `CHIP_PU` 走线尽量短。

### 6. IO0 BOOT 按键建议加上拉或确认内部上拉足够

截图中 IO0 有按键和 100nF 电容。

建议检查：

- IO0 正常启动时是否为高电平。
- 是否需要外部 10kΩ 上拉到 3.3V。
- BOOT 按键按下是否拉到 GND。

通常 IO0 有内部上拉，但第一版为了调试稳定，可以预留外部上拉电阻焊盘。

### 7. 3.3V LDO 电流能力要留余量

当前使用的是 `SGM2212-3.3` 类 LDO。

需要确认：

- 最大输出电流是否足够 ESP32-S3 Wi-Fi 峰值。
- LDO 从 5V 降到 3.3V 时发热是否能接受。
- 摄像头和舵机不要共用这个 3.3V。

ESP32-S3 + Wi-Fi + 摄像头时，3.3V 电源建议至少按 `500mA` 以上设计。

如果后续还有音频、SD 卡等，建议考虑更高余量或使用 DCDC。

### 8. 天线禁布区现在必须提前规划

你用的是 WROOM-1 PCB 天线版本。

PCB 版图时必须：

- 模组天线伸出板边最好。
- 天线下方所有层禁止铺铜。
- 天线周围不要放 USB、舵机、电池、排线、金属螺丝。
- 外壳也不要在天线附近放金属件。

如果外壳空间不好安排，可以改用 `WROOM-1U` 外接天线。

## 四、建议你下一步画图顺序

### 第 1 步：先把原理图电源补完整

- [ ] USB-C 5V 输入
- [ ] 5V 入口 ESD / 保险丝 / 大电容
- [ ] 3.3V 给 ESP32-S3
- [ ] 2.8V 给 OV3660 AVDD
- [ ] 1.8V 给 OV3660 DOVDD
- [ ] 舵机 5V 独立支路
- [ ] 每一路电源测试点

### 第 2 步：确认 ESP32-S3 基础电路

- [ ] 3V3 和 GND 全接
- [ ] EPAD 接 GND
- [ ] CHIP_PU 上拉、延时、电容、复位按键
- [ ] IO0 BOOT 按键
- [ ] USB D+ / D- 接 GPIO20 / GPIO19
- [ ] U0TXD / U0RXD 引出测试点或排针
- [ ] Strapping 引脚没有被外部电路错误拉高/拉低

### 第 3 步：确认摄像头接口

- [ ] 用 OV3660 数据手册逐脚核对。
- [ ] 24pin 排线座方向确认。
- [ ] AVDD / DOVDD / DVDD 处理正确。
- [ ] SIOC / SIOD 有上拉。
- [ ] RESET / PWDN 接 GPIO。
- [ ] XCLK / PCLK / VSYNC / HREF 连接正确。
- [ ] D9..D2 接 ESP32-S3。
- [ ] D1 / D0 明确不接。

### 第 4 步：再考虑扩展功能

- [ ] 舵机接口。
- [ ] I2S 麦克风。
- [ ] I2S 功放。
- [ ] microSD。
- [ ] 备用电池接口。

第一版不建议把扩展功能画得太复杂，先保证主功能能跑。

## 五、PCB 版图学习重点

### 1. 先学会看电源回路

重点理解：

- 电流从哪里来。
- 经过哪个芯片。
- 从哪里回到 GND。
- 大电流路径是否绕远。
- 电容是否靠近用电芯片。

### 2. 再学会分高速和低速

这个项目中比较敏感的是：

- USB D+ / D-
- OV3660 DVP 数据线
- PCLK
- XCLK
- ESP32-S3 天线区域

这些线不要随便绕来绕去。

### 3. 学会放测试点

第一版 PCB 不是为了好看，是为了能调试。

建议测试点：

- 5V
- 3V3
- 2V8
- 1V8
- GND
- CHIP_PU
- IO0
- USB D+
- USB D-
- SIOC
- SIOD
- PCLK
- VSYNC
- HREF
- PWDN
- RESET

### 4. 学会保留 0Ω 电阻

建议在这些地方预留 0Ω：

- `VCC_3V3 -> ESP_3V3`
- 摄像头电源入口
- 舵机电源入口
- 关键时钟或高风险信号

作用是调试时可以断开、测电流、排查短路。

## 六、当前项目的最小打板前检查清单

打板前至少确认：

- [ ] Type-C CC1 / CC2 均为 5.1kΩ 到 GND。
- [ ] USB D+ / D- 正反插两组数据脚合并正确。
- [ ] USB D+ 到 GPIO20，D- 到 GPIO19。
- [ ] 3.3V LDO 电流和发热满足要求。
- [ ] 2.8V 和 1.8V 摄像头电源已画完整。
- [ ] ESP32-S3 所有 GND / EPAD 接地。
- [ ] CHIP_PU 不悬空，RC 参数正确。
- [ ] IO0 BOOT 电路能正常下载。
- [ ] 摄像头 24pin 引脚和 OV3660 手册一致。
- [ ] 天线禁布区完整。
- [ ] 所有电源都有测试点。
- [ ] 原理图 ERC 无严重错误。
- [ ] PCB DRC 无严重错误。

## 七、资料来源

- Espressif ESP32-S3 Hardware Design Guidelines: https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32s3/index.html
- Espressif ESP32-S3 Schematic Checklist: https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32s3/schematic-checklist.html
- Espressif ESP32-S3 PCB Layout Design: https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32s3/pcb-layout-design.html
- ESP32-S3-WROOM-1 / WROOM-1U Datasheet: https://www.espressif.com/sites/default/files/documentation/esp32-s3-wroom-1_wroom-1u_datasheet_en.pdf
- Espressif esp32-camera Component: https://components.espressif.com/components/espressif/esp32-camera
- Microchip USB Type-C CC Resistors: https://onlinedocs.microchip.com/oxy/GUID-DAF68E19-EB64-4E93-83DB-9E883647B776-en-US-1/GUID-02E3AD6F-2676-4B83-9D2E-31D93E162FA3.html

