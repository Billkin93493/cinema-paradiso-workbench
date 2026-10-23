# 可选本机工具

此目录不随仓库分发 FFmpeg 二进制。可自行安装至 `/opt/homebrew/bin/ffmpeg` 或 `/usr/local/bin/ffmpeg`，也可以把自行取得并已核实许可的可执行文件放到本目录，命名为 `ffmpeg`，赋予可执行权限后再构建。

`build.sh` 只在本目录存在可执行 `ffmpeg` 时将它复制到应用包。重新分发包含 FFmpeg 的应用前，需补齐对应构建的许可与源码等材料。见根目录 `THIRD_PARTY_NOTICES.md`。
