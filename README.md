# 新天堂电影院 · 导演工作台

**把一次拉片，变成可以反复使用的导演资料。**

面向导演与影视学生的本地拉片工具。导入电脑里的电影、广告或短片，自动检测切镜，再把静帧、片段位置、标签和导演笔记整理成自己的影像资料库。

Cinema Paradiso Workbench is a local-first film analysis and visual reference library for directors and film students. The full desktop implementation uses Swift and WebKit on macOS.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111827)
![Apple Silicon](https://img.shields.io/badge/Apple-Silicon-64748b)
![Version 0.9.0](https://img.shields.io/badge/version-0.9.0-blue)
![MIT License](https://img.shields.io/badge/license-MIT-blue)

> 当前公开的是 **0.9.0 内部测试版源码**。完整功能以 macOS 原生版为准；Windows、Intel Mac、正式云端账号与云端备份尚未支持。本仓库暂不提供安装包。

## 可以做什么

- **拉片**：导入本地影片，播放、逐帧、倍速、跳转；自动检测切镜，人工增加、移动或删除切点。
- **逐镜记录**：镜号、入点、出点、时长、代表静帧，以及景别、机位、运镜和导演笔记。
- **辅助分析**：在本机识别人物数量、昼夜与室内外；结果可以人工检查和修改。
- **字幕对白**：读取已有文字字幕，按镜头时间对应并人工校正；可手动启用云端画面字幕提取。
- **导演资料库**：收藏静帧与片段位置，使用标签、搜索、筛选和主题收藏夹，并返回原影片对应时间码。
- **灵感与结构**：图片、文字卡片、灵感板，以及每部影片独立的结构画板。
- **导出与备份**：PDF 拉片报告、图文 Excel、静帧资料包、本地备份与合并恢复。

自动切镜与识别结果是辅助建议，需要人工复核。片段收藏默认记录原片的起止位置，不复制整部影片。

## 运行完整的 Mac 版

需要 Apple Silicon Mac、macOS 13 或更新版本，以及 Apple Command Line Tools（包含 Swift 编译器）。

```sh
git clone https://github.com/Billkin93493/cinema-paradiso-workbench.git
cd cinema-paradiso-workbench
zsh macos/build.sh
open 'dist-native/0.9.0/新天堂电影院·导演工作台.app'
```

未安装编译工具时，可运行 `xcode-select --install`，按系统提示安装后再构建。**原生构建不需要 Node.js、npm 或 Electron。**

构建结果采用本地临时签名，未经过 Apple Developer ID 签名或公证。公开安装包需要另行完成签名、公证和安装验证。

### 可选：FFmpeg

部分系统无法直接读取的视频，需要 FFmpeg 生成兼容副本。仓库不附带 FFmpeg 二进制文件。Mac 版会依次查找应用包内的 `ffmpeg`、`/opt/homebrew/bin/ffmpeg` 和 `/usr/local/bin/ffmpeg`。

如已安装 Homebrew，可自行执行：

```sh
brew install ffmpeg
```

也可以将自行取得、已确认许可的可执行文件放入 `macos/Tools/ffmpeg` 后重新构建；再次分发时需履行对应构建的许可要求，见 [第三方说明](THIRD_PARTY_NOTICES.md)。没有 FFmpeg 时，软件仍会尝试系统的媒体处理能力，但兼容范围可能缩小。

## 只预览界面

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

打开 [本地界面预览](http://127.0.0.1:4173/preview/)。浏览器预览包含演示数据，不具备完整原生处理能力，也不代表真实影片已经导入。

`desktop/` 是早期 Electron 外壳，可通过 `npm ci` 与 `npm start` 查看；它没有实现 Swift 原生版的完整接口，不作为当前正式运行入口。相关依赖版本保留原项目锁定记录。

## 隐私与数据

原始影片默认留在电脑。本地切镜、代表静帧、基础识别、笔记和资料整理在本机完成。

只有主动点击云端字幕提取，才会把抽取并压缩后的字幕区域画面发送给 OpenAI，由使用者提供自己的密钥并承担费用。密钥通过 macOS 钥匙串保存，不随项目或备份导出。本次开源验证没有调用付费云端服务，云端识别效果仍需自行测试。

当前“轻账号”只保存本机昵称和邮箱，不创建云端账号；云端备份仍是预留能力。

仓库不含原始电影、个人拉片记录、账号密钥、本地备份和真实影片测试导出。演示图由维护者确认可以公开；见 [素材与依赖说明](THIRD_PARTY_NOTICES.md)。

## 项目结构

| 路径 | 用途 |
| --- | --- |
| `macos/` | Swift 原生程序、媒体处理、导出、备份与工作流测试 |
| `preview/` | 共用的 HTML / CSS / JavaScript 界面与演示素材 |
| `report/` | 报告页面；Python 脚本为历史演示报告生成器 |
| `desktop/` | 早期 Electron 外壳 |
| `docs/` | 开发、验证与开源整理说明 |

更多细节见 [开发说明](docs/DEVELOPMENT.md)、[当前状态](docs/STATUS.md) 和 [本次验证记录](docs/VALIDATION.md)。

## 参与改进

欢迎提交问题与 Pull Request。反馈请包含系统版本、复现步骤、预期与实际结果；不要上传完整商业影片、私有项目或密钥。详见 [贡献说明](CONTRIBUTING.md)。

优先方向：真实素材兼容性、切镜误差、保存与恢复可靠性、导出质量，以及可复现的测试。Intel Mac、Windows、官方签名与云端备份属于后续工作。

## 许可

项目原创代码按 [MIT License](LICENSE) 开源。第三方依赖按各自协议使用；本协议不授予第三方电影、人物或商标的使用权。本工具仅处理使用者有权使用的本地视频，不提供影视资源搜索、下载或受保护视频解析。
