# 开发与验证

## 两种桌面实现

- `macos/`：Swift + AppKit + WKWebView，承载当前完整功能。`macos/build.sh` 列出主程序编译单元，测试文件不进入主程序。
- `desktop/`：早期 Electron 外壳，只实现部分桥接接口。`npm start` 不代表完整 0.9.0 原生功能。
- `preview/`：两种桌面实现共用的页面。普通浏览器可预览界面与演示数据。
- `report/`：报告 HTML / CSS / JavaScript。Python 脚本是历史演示工具，使用 ReportLab 与本机中文字体。

## 原生构建

在仓库根目录执行 `zsh macos/build.sh`。需要 macOS 13+、Apple Silicon 与 Apple Swift 工具链。输出为 `dist-native/0.9.0/新天堂电影院·导演工作台.app`；不会修改 `/Applications` 中已安装的应用。

构建脚本只打包界面、报告和必要图标；`output/` 是本机导出目录，不进入应用包。FFmpeg 是可选的本机依赖，详情见根目录第三方说明。

## 静态检查

如已安装 Node.js，可在根目录执行：

```sh
node --check preview/script.js
node --check report/script.js
node --check desktop/main.js
node --check desktop/preload.js
zsh -n macos/build.sh
plutil -lint macos/Info.plist
```

## 既有工作流测试

`macos/*WorkflowTest.swift` 以合成数据或桥接替身覆盖各项交互。其中部分测试需要可运行的 macOS 图形登录会话、WKWebView 或外部样片；不要将编译通过写成真实交互通过。

例如 Excel 导出检查，不需要原始电影：

```sh
mkdir -p tmp
xcrun swiftc -parse-as-library -framework AppKit \
  macos/ExcelExporter.swift macos/ExcelWorkflowTest.swift \
  -o tmp/ExcelWorkflowTest
./tmp/ExcelWorkflowTest
```

输出位于 `tmp/xlsx/`。应检查 XLSX ZIP 中的工作表、时间码、字幕和图片，而不只检查进程退出码。

切点时间输入检查（需要图形登录会话）：

```sh
xcrun swiftc -parse-as-library -framework Cocoa -framework WebKit \
  macos/ShotTimeFieldWorkflowTest.swift -o tmp/ShotTimeFieldWorkflowTest
./tmp/ShotTimeFieldWorkflowTest
```

检查输出是否包含测试成功标记；部分旧测试在超时时仍正常退出，因此退出码不足以判定通过。

请在独立环境进行真实影片、保存恢复与钥匙串验证，不让测试触碰已有个人资料。云端真实请求会上传数据并可能收费，不属于默认测试范围。
