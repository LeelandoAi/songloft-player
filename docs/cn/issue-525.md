# Issue #525：大播放队列卡顿

关联：[songloft-org/songloft#525](https://github.com/songloft-org/songloft/issues/525)。报告环境为 Docker 2.13.3 后端、Windows / 手机客户端、约 3 万首曲库。

## 行为与实现

确认了两处大队列开销：手机弹窗和桌面侧栏虽然按固定高度计算自动定位，却没有向 `ReorderableListView.builder` 提供行高。远距离跳位会布局大量中间行，连带创建封面和标题组件。另外，`PlayQueue.add` 为每首新增歌曲扫描一次整个队列，后台补齐大队列时同步计算随队列增长。

两处列表现在通过 `itemExtent` 直接计算可见索引，与自动定位及手机滚动条共用行高；行高按实际字体和文字缩放增大。大数字徽标与英文标题的横向空间也做了约束。追加通过 `(id, type)` 集合查重，保留批次顺序、既有重复项和当前索引。

## 验证对象与环境

- 时间：2026-10-15。主仓库基线 `f9c17dc9ee6a98652a929c238be142e2b33fd817`，Flutter 基线 `00cbe94841acca3eaf561a339f61072914c9de31` + 本次未提交工作树。文件哈希、diff 哈希和构建哈希见 `/tmp/songloft-525/validation.json`。
- Linux amd64；Flutter **3.44.8** stable、Dart **3.12.2**（安装目录仍名为 `3.41.5`，版本以工具实际输出为准）；Docker browserless Chrome。
- 后端使用主仓库基线构建的 `dev,lite` 二进制和临时 SQLite 数据库，执行真实迁移后注入 30,000 条合成歌曲。音频为生成的静音 WAV，封面为生成的 PNG，没有使用私人曲库。

## 自动检查

| 检查 | 结果与证据 |
|---|---|
| `dart format lib/ test/`、`git diff --check` | 通过，无额外格式差异 |
| `flutter test --no-pub` | 728 项通过，`/tmp/songloft-525/all-tests.log` |
| `flutter analyze --no-pub` | 通过，`analyze-final.log` |
| 父仓库执行 `bash clients/player/scripts/build-frontend.sh web-embedded /tmp/songloft-525/build` | 通过，`build.log` |
| 旧源码反向回归 | 隔离 `git archive` 的基线项目，两处列表定位到第 15,001 首均触发超过 200 行的保护；追加 100 首读取 ID 6,000,000 次，未达到 30,100 次上限。日志 `before-layout.log`、`before-mobile.log`、`before-add.log` |
| 修复后回归 | 打开首部、中部、末尾及远距离切歌，每阶段读取队列条目少于 100 次；覆盖中英文、两倍字号、拖拽排序、播放与删除回调。真实队列值对象测试覆盖批内/批间重复及顺序 |

## 真实浏览器

- 英文桌面 1200×900、中文手机 390×900，分别恢复完整 30,000 首队列并在第 15,001 / 30,000 首播放时打开队列，当前项可见、徽标为 30000，可关闭并继续操作。累计封面请求分别为 39、36、24、22 个，页面异常为零。
- 记录实际 `HTMLMediaElement`（包括未挂载 DOM 的元素），确认打开/关闭后音频未暂停，时间推进至约 4.9～5.7 秒。截图只用于检查布局与封面，不作为播放证据。
- 真实点击曲库「播放全部」，按现有 10 首首批 + 100 首后台批次完成 30,000 首加载，再打开桌面播放队列，计数为 30000。合成数据本机此次后台加载约 86.7 秒，不是设备性能保证。
- 证据：`/tmp/songloft-525/browser-results.json`、`browser-mobile.log`、`queue-{en,zh}-{15000,29999}.png`、`playall-fixed.log`、`playall-queue.json`、`playall-queue.png`。测试脚本捕获了真实媒体元素的引用，没有向产品代码添加测试接口。
- 初期使用已有旧 Web 产物探测完整加载，120 秒截止前未完成（`baseline-playall-4.log`）；该产物未绑定本次基线 SHA，不将其描述为原生卡死复现或同 SHA 性能对比。确定性的反向验证以隔离源码测试为准。

## 边界与交付

Not run：Windows / Android 原生构建、报告人的真机与私人曲库验收；本机没有这些目标设备。后端完整测试不适用：未修改后端或 API。浏览器和 Widget 测试验证共享 Flutter 列表机制，不替代原生环境验收。

本次仅修改 Flutter 子仓库，按用户授权提交到本地 `main`，随后由父仓库提交 gitlink 更新；具体 SHA 以 Git 记录为准。未推送、发布或评论 Issue。提交信息：`fix(player): 优化大播放队列定位与批量追加 songloft-org/songloft#525`。
