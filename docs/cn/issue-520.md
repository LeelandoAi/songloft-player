# 歌词页屏幕常亮 · songloft-org/songloft#520

2026-10-14。范围为客户端常亮配置；退出/清后台问题按用户要求暂不处理。

## 行为

「设置 → 播放设置 → 歌词页屏幕常亮」位于自动进入歌词选项之后。默认关闭，偏好 `player_lyrics_keep_screen_on` 仅保存到本机。手机仅在歌词页可见时保持亮屏；宽屏为并列歌词。暂停仍生效，返回封面、覆盖播放器路由、离开页面或应用退后台时释放，前台恢复可见歌词时重新申请。

复用已由 `media_kit_video` 引入并注册的 `wakelock_plus 1.5.2`；只提升为直接依赖，不新增原生插件或 Kotlin 方法。歌词和原生视频共用带所有者集合、串行原生写入的控制器，释放歌词不会取消视频请求。浏览器拒绝或不支持时不影响播放。

## 验证对象与结果

- 仓库：`songloft-org/songloft-player`，基线 `57db9766ac36b58f136b4e7ae41a2d1c51a079ce` + 未提交工作树。源码 SHA-256 `4ee8dddc9c095b05e25cd891e1ff7e66b245dfe902c9bd97d9d02c6ec1be863d`；算法和路径范围见 `/tmp/songloft-520-validation.json`（`git diff --binary` 加范围内未跟踪文件路径及内容，文档不计入源码标识）。
- 环境：Linux、Flutter 3.41.5、Web embedded；浏览器为 Docker `browserless/chrome:latest`。UI 使用隔离服务端/临时数据库，未操作现有用户数据。
- `dart format lib/ test/`、`flutter analyze --no-pub`、`flutter test --no-pub --reporter expanded` 通过，完整测试 696 项；新测试包含缺省/恢复、初始化竞态、快速写入、前后台、路由覆盖、卸载、歌词/视频并发所有权和迟到原生调用。
- `flutter build web --no-pub --no-web-resources-cdn --dart-define=DEPLOY_MODE=embedded --output /tmp/songloft-520-flutter-web` 通过。沿真实 UI 登录并进入播放设置、开启常亮，本机 `flutter.player_lyrics_keep_screen_on` 实际保存为 `true`，页面异常为空；截图 `/tmp/songloft-520-flutter-toggle.png`，结果 `/tmp/songloft-520-flutter-settings-ui.json`。
- 日志：`/tmp/songloft-520-flutter-{focused,analyze,build,tests-final}.log`。格式、差异及 UTF-8 检查通过。
- Not run：Android/iOS/桌面的真实熄屏和视频交接验收，无连接设备；Flutter Web 的物理熄屏与系统电源策略未验收，截图/持久化不能替代该行为验证。

上述验证执行于提交前；用户随后授权提交、推送及回复 Issue。最终提交以 Git 记录为准，推送后的 CI/开发包状态以同一 SHA 的工作流为准；本批不打正式版 tag。现有 v2.13.1 安装包不包含本批功能。报告人的鸿蒙 4.2 截图与 Flutter Android 版一致，安装方式仍需本人确认；Lynx HAP 面向 HarmonyOS NEXT，不能将其直接当成 4.2 的替代安装包。
