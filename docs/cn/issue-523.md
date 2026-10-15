# 歌词可读性与内置配色 · songloft-org/songloft#523

2026-10-15，关联 [songloft-org/songloft#523](https://github.com/songloft-org/songloft/issues/523)。本批修改 Flutter 手机与桌面全屏播放器及外观设置。

## 行为与原因

- 原全屏背景把封面、darkMutedColor、主题渐变及黑色顶部遮罩叠加，歌词却仍直接使用主题 primary；亮色模式背景被压暗，歌词与背景没有协同计算。译文和罗马音额外降低透明度，进一步降低对比度。
- 手机和桌面共用 `PlayerBackdrop`：封面颜色混合到主题 surface，生成柔和渐变；不再绘制全屏模糊图层或黑色顶罩。Windows 同样使用取色渐变，避免历史 saveLayer 问题。
- 封面缺失、加载中、失败均回到主题默认渐变；不会按歌曲元数据生成不同的兜底背景。主题包的 playerGradient 首尾色用于默认渐变，封面取色可用时优先使用封面。增强对比度使用纯色 surface。
- 当前行、翻译、罗马音和逐字歌词共用按背景加强的主题强调色，目标对比度 7:1；其他歌词目标 4.5:1。顶部文字和按钮使用 onSurface。
- 外观设置提供星蓝、青碧、森绿、玫瑰、琥珀、紫藤六种内置配色，适配浅色/深色/系统模式。设备偏好 `built_in_palette` 不参与服务器同步；服务器主题包优先，恢复默认后重新使用设备保存的配色。中、英、西班牙文文案已生成。

## 验证对象

- `songloft-org/songloft-player` 基线 `b80e03b47eefb1aaedf07d611b1d9d3c3d48257b` + 未提交工作树，源码标识 `1eac2d6a16e45e318fe1325d5f29db00e965279c3429a99d1c7c0b3385bc8185`。算法：`git diff --binary -- lib test`，追加排序后的未跟踪 lib/test 路径、NUL、内容、NUL，再计算 SHA-256；不含文档。
- 父仓库基线 `9d008b8026abb56a2ee3aae29f71017460bcc1af`，本批仅修改相关双语文档；子模块仍为 dirty，未提交新指针。
- Linux amd64、Flutter 3.41.5、Web embedded、Docker browserless/Chrome 121。使用临时数据库及合成 WAV/封面/歌词，不操作用户曲库。

## 验证结果

- `dart format lib/ test/`、`flutter analyze --no-pub` 通过；`flutter test --no-pub` 全部 716 项通过。扩展后的两个新测试文件共 8 项通过，覆盖六种配色、亮暗模式、极端封面、渐变采样、增强对比度、翻译/逐字高亮、启动时选择、快速写入、恢复、主题包优先及实际 App 切换。
- 隔离副本只换回基线 `lyrics_view.dart`：亮/暗模式两项渲染回归按预期失败（分别在当前行 5.17:1 和译文 5.82:1 处低于 7:1 目标），不是编译失败。原工作树未被回退。
- `make build-frontend-web-embedded` 及 `go build -tags dev -o /tmp/songloft-523/server .` 通过。
- 浏览器完整结果见 `/tmp/songloft-523/browser-results.json`；背景像素比对见 `background-pixels.json`。手机中文浅色与桌面英文深色均从首页应用内进入播放器，切换珊瑚/海蓝/无封面/失效封面，检查歌词、默认背景和工具栏；外观页选择玫瑰后检查 localStorage，并刷新根页后应用内重新进入外观确认选中态恢复。截图见同目录 `zh-light-*.png`、`en-dark-*.png`、`*-settings-rose.png`。
- 日志与完整工作树对象见 `/tmp/songloft-523/{validation.json,analyze-final.log,all-tests.log,expanded-tests.log,before-lyrics.log,web-build.log,browser.log}`。
- Not run：Android/iOS/Windows/macOS/Linux 原生客户端构建及真机户外验收；本批未改原生桥接、音频或后端 API。Web 不能替代原生设备验收。

## 效果截图与交付

代表性原图：[手机浅色歌词](../assets/issue-523/light.png) · [桌面深色歌词](../assets/issue-523/dark.png) · [玫瑰配色设置](../assets/issue-523/palette.png)。完整 59 张跨客户端截图及验证记录保留在 `/home/hanxi/work/songloft-review/issue-523-lynx-20261015/`。

2026-10-15 用户已授权提交、推送和回复 songloft-org/songloft#523；先提交两个客户端，再更新父仓库指针。以上工作树状态为验证阶段快照，最终提交和开发包状态按 Git/同一 SHA 的 CI 核对。本批不打正式版 tag，不关闭 Issue。
