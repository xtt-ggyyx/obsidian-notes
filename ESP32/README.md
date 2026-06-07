# ESP32 笔记总入口

这个目录用于整理 ESP32 相关项目和学习笔记。

## 当前重点项目

### [[cat_watch_esp32s3/README|ESP32-S3 + OV3660 猫咪看护项目]]

这是当前正式项目目录。

主要内容：

- 自研 PCB 计划。
- OV3660 摄像头。
- ESP32-S3 本地猫检测。
- 手机网页查看视频。
- 区域配置和行为判断。
- 舵机和 3D 外壳。

常用入口：

- [[cat_watch_esp32s3/项目进度总表|项目进度总表]]
- [[cat_watch_esp32s3/docs/问题记录|问题记录]]
- [[cat_watch_esp32s3/docs/项目总体计划|项目总体计划]]
- [[cat_watch_esp32s3/docs/项目优化建议|项目优化建议]]
- [[cat_watch_esp32s3/hardware/第一版PCB引脚分配|第一版 PCB 引脚分配]]
- [[cat_watch_esp32s3/hardware/电源设计|电源设计]]
- [[cat_watch_esp32s3/hardware/3D外壳打印和装配说明|3D 外壳打印和装配说明]]
- [[cat_watch_esp32s3/docs/换电脑继续项目指南|换电脑继续项目指南]]

## 旧目录

### `cat_watch_esp32`

这是之前创建的临时目录，目前只有空白笔记，不是正式项目。

正式项目请使用：

```text
cat_watch_esp32s3
```

## 建议整理规则

- 项目总计划放在项目根目录或 `docs/`。
- 原理图、PCB、电源、BOM、外壳资料放在 `hardware/`。
- 固件代码放在 `firmware/`。
- 工具脚本放在 `tools/`。
- 临时问题和结论统一写进 `docs/问题记录.md`。
- 每完成一个阶段，更新 `项目进度总表.md`。

