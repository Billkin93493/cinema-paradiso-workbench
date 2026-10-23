# 第三方依赖与素材

## 原生 Mac 版

原生版使用 macOS 的 AppKit、AVFoundation、Vision、Security 和 WebKit。构建需要 Apple 提供的 SDK 与工具链；本仓库不重新分发这些框架或系统字体。

## FFmpeg

原始私有目录含一个 FFmpeg 可执行文件，未附完整来源、构建配置及许可材料，因此本次源码发布不分发该二进制，也不发布包含它的旧 DMG / PKG。

使用者可以自行安装 FFmpeg。FFmpeg 的具体许可取决于构建配置；自行打包分发时，应检查该构建的许可、源码获取方式及其他分发要求。可从 [FFmpeg 官方许可页面](https://ffmpeg.org/legal.html) 开始核查。本项目的 MIT 协议不覆盖 FFmpeg。

## Electron 开发外壳

`package.json` 与 `package-lock.json` 保留原项目的 Electron 及打包工具依赖。仓库不包含 `node_modules` 或 Electron 二进制。安装和再次分发时，需保留各依赖自带的许可与第三方声明。完整原生版不依赖 Electron。

## 演示图片与图标

`preview/assets/still-*.png` 和 `fictional-film-contact-sheet.png` 用于虚构演示影片《潮汐之后》；维护者于 2026-10-23 明确确认这些图片可以随项目公开。制作方式未在本次整理中独立核实，不将其表述为真实影片截图或已核实的 AI 作品。

应用图标沿用原项目资源。本次没有导入新的第三方图片或字体文件，也没有将真实电影测试静帧加入仓库。

## 历史 Python 报告工具

`report/generate_report.py` 是演示用途的辅助脚本，依赖 ReportLab 和 macOS 系统中文字体；当前原生版的报告预览与打印不要求执行该脚本。ReportLab 按自身许可使用，系统字体不随仓库分发。
