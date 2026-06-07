# Obsidian 配置备份说明

记录日期：2026-06-07

这份笔记用于换电脑时恢复 Obsidian 使用环境。

当前仓库的 Obsidian 配置目录：

```text
.obsidian/
```

## 换电脑恢复顺序

1. 安装 Git。
2. 安装 GitHub Desktop。
3. Clone 这个 Obsidian 仓库。
4. 安装 Obsidian。
5. 在 Obsidian 里打开 clone 下来的仓库目录。
6. 检查 `.obsidian` 配置是否被识别。
7. 打开设置，确认第三方插件已经启用。
8. 检查 Git 插件是否能正常提交和推送。

## 当前基础设置

来自 `.obsidian/app.json`：

| 设置 | 当前值 | 说明 |
| --- | --- | --- |
| 删除文件时是否提示 | `false` | 删除时不弹确认提示，需要小心 |
| 自动更新内部链接 | `true` | 重命名文件时自动更新链接 |
| 附件目录 | `./attachment` | 图片和附件默认放到仓库下的 `attachment` 文件夹 |

## 外观设置

来自 `.obsidian/appearance.json`：

当前没有记录特殊主题配置。

说明：

- 没有看到自定义主题名称。
- 换电脑后如果界面不一样，优先检查 Obsidian 默认主题和外观设置。

## 已启用第三方插件

来自 `.obsidian/community-plugins.json`：

| 插件 ID | 插件名 | 当前版本 | 用途 |
| --- | --- | --- | --- |
| `obsidian-git` | Git | 2.35.2 | 在 Obsidian 里做 Git 备份、提交和推送 |
| `obsidian-excalidraw-plugin` | Excalidraw | 2.18.3 | 画图、草图、结构图 |
| `image-converter` | Image Converter | 1.3.18 | 图片转换、压缩、裁剪、标注 |
| `editing-toolbar` | Editing Toolbar | 3.2.1 | 类似 Word 的编辑工具栏 |
| `highlightr-plugin` | Highlightr | 1.2.2 | 文字高亮颜色菜单 |

## 已安装但当前未启用的插件

在 `.obsidian/plugins/` 中存在，但没有出现在启用列表中：

| 插件 ID | 插件名 | 当前版本 | 说明 |
| --- | --- | --- | --- |
| `obsidian-markdown-formatting-assistant-plugin` | Markdown Formatting Assistant | 0.4.1 | 已安装但未启用，需要时再打开 |

## 核心插件启用状态

来自 `.obsidian/core-plugins.json`。

### 已启用

- 文件列表：`file-explorer`
- 全局搜索：`global-search`
- 快速切换：`switcher`
- 图谱：`graph`
- 反向链接：`backlink`
- Canvas：`canvas`
- 出链：`outgoing-link`
- 标签面板：`tag-pane`
- 属性：`properties`
- 页面预览：`page-preview`
- 日记：`daily-notes`
- 模板：`templates`
- 笔记组合：`note-composer`
- 命令面板：`command-palette`
- 编辑器状态：`editor-status`
- 书签：`bookmarks`
- 大纲：`outline`
- 字数统计：`word-count`
- 文件恢复：`file-recovery`
- Obsidian Sync：`sync`
- Bases：`bases`

### 未启用

- 脚注：`footnotes`
- 斜杠命令：`slash-command`
- Markdown 导入器：`markdown-importer`
- Zettelkasten 前缀器：`zk-prefixer`
- 随机笔记：`random-note`
- 幻灯片：`slides`
- 录音机：`audio-recorder`
- 工作区：`workspaces`
- 发布：`publish`
- Web Viewer：`webviewer`

## 快捷键

来自 `.obsidian/hotkeys.json`。

当前自定义快捷键：

| 功能 | 快捷键 |
| --- | --- |
| 插入代码块 | `Ctrl + Shift + Z` |

说明：

- 配置里写的是 `Mod + Shift + Z`。
- Windows 上 `Mod` 通常对应 `Ctrl`。
- macOS 上 `Mod` 通常对应 `Command`。

## 命令面板

来自 `.obsidian/command-palette.json`。

当前没有固定命令：

```json
{
  "pinned": null
}
```

## 图谱设置

来自 `.obsidian/graph.json`。

当前主要设置：

- 折叠过滤器：开启。
- 显示标签：关闭。
- 显示附件：关闭。
- 隐藏未解析链接：关闭。
- 显示孤立笔记：开启。
- 显示箭头：关闭。
- 节点大小倍率：`1`
- 连线大小倍率：`1`
- 中心力：约 `0.519`
- 排斥力：`10`
- 链接距离：`250`

## Editing Toolbar 插件配置

配置文件：

```text
.obsidian/plugins/editing-toolbar/data.json
```

当前特点：

- 工具栏位置：顶部。
- 启用顶部工具栏。
- 不启用跟随工具栏。
- 不启用固定工具栏。
- 不启用移动端加载。
- 包含撤销、重做、标题、加粗、斜体、删除线、下划线、高亮、表格、任务列表、引用、代码块、链接、列表、对齐、字体颜色、背景色等按钮。

换电脑后如果编辑工具栏不见了：

1. 确认 `Editing Toolbar` 插件已启用。
2. 检查插件设置里的工具栏位置是否为顶部。
3. 检查 `.obsidian/plugins/editing-toolbar/data.json` 是否存在。

## Excalidraw 插件配置

配置文件：

```text
.obsidian/plugins/obsidian-excalidraw-plugin/data.json
```

当前重要设置：

| 设置 | 当前值 |
| --- | --- |
| 默认绘图目录 | `Excalidraw` |
| 模板文件 | `Excalidraw/Template.excalidraw` |
| 脚本目录 | `Excalidraw/Scripts` |
| 字体目录 | `Excalidraw/CJK Fonts` |
| 自动保存 | 开启 |
| 桌面自动保存间隔 | 60000 ms |
| 移动端自动保存间隔 | 30000 ms |
| 文件名前缀 | `Drawing ` |
| 文件名时间格式 | `YYYY-MM-DD HH.mm.ss` |
| 使用 `.excalidraw` 扩展名 | 开启 |
| 预览图片类型 | `SVGIMG` |
| 打开时缩放到适合窗口 | 开启 |

注意：

- 当前 `loadChineseFonts` 是 `false`。
- 如果新电脑上 Excalidraw 中文显示异常，再检查字体设置。

## Git 插件配置

插件目录：

```text
.obsidian/plugins/obsidian-git/
```

当前仓库里没有发现：

```text
.obsidian/plugins/obsidian-git/data.json
```

说明：

- Git 插件已安装并启用。
- 但具体自动备份间隔、提交消息模板等设置没有在仓库里看到配置文件。
- 换电脑后需要打开插件设置手动确认。

建议换电脑后检查：

- 是否启用 `Git` 插件。
- 自动 pull 是否开启。
- 自动 commit-and-sync 是否开启。
- 自动备份间隔是多少。
- 提交消息模板是否符合习惯。
- GitHub 登录凭据是否可用。

## Image Converter 插件

插件目录：

```text
.obsidian/plugins/image-converter/
```

用途：

- 图片转换。
- 图片压缩。
- 图片裁剪。
- 图片标注。
- 图片对齐。

当前还存在：

```text
.obsidian/plugins/image-converter/image-converter-image-alignments.json
```

换电脑后如果图片工具不可用，先确认插件是否启用。

## Highlightr 插件

插件目录：

```text
.obsidian/plugins/highlightr-plugin/
```

用途：

- 给文字添加不同颜色高亮。
- 适合做资料阅读和重点标注。

## Markdown Formatting Assistant 插件

插件目录：

```text
.obsidian/plugins/obsidian-markdown-formatting-assistant-plugin/
```

当前状态：

- 已安装。
- 未启用。

如果需要更多 Markdown 格式按钮，可以手动启用。

## 哪些配置文件要同步

建议提交到 GitHub：

```text
.obsidian/app.json
.obsidian/appearance.json
.obsidian/community-plugins.json
.obsidian/core-plugins.json
.obsidian/hotkeys.json
.obsidian/command-palette.json
.obsidian/graph.json
.obsidian/plugins/*/manifest.json
.obsidian/plugins/*/data.json
```

当前仓库已经包含插件的 `main.js` 和 `styles.css`，所以新电脑 clone 后通常可以直接使用插件。

## 换电脑后检查清单

- [ ] Obsidian 能打开仓库。
- [ ] `.obsidian` 配置被识别。
- [ ] 附件目录仍为 `./attachment`。
- [ ] 删除文件时不提示，这个行为符合预期。
- [ ] 内部链接重命名时自动更新。
- [ ] Git 插件已启用。
- [ ] Excalidraw 插件已启用。
- [ ] Image Converter 插件已启用。
- [ ] Editing Toolbar 插件已启用。
- [ ] Highlightr 插件已启用。
- [ ] Markdown Formatting Assistant 保持未启用，除非需要。
- [ ] `Ctrl + Shift + Z` 能插入代码块。
- [ ] Git push 能成功。
- [ ] ESP32 项目入口能打开：`ESP32/README.md`。

## 重要提醒

不要把下面这些内容写进笔记或提交到 GitHub：

- GitHub token。
- SSH 私钥。
- Wi-Fi 密码。
- 个人账号密码。
- 云服务器密码。

