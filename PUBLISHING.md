# 公开发布清单

仓库：https://github.com/maxhoov/VirtualBoyPocket

本地准备不代表已上传或已被 Pocket Sync 收录。

1. 将对应源码、构建脚本和文档上传仓库，保留 LICENSE 和各文件的上游版权声明。不要上传 rom/、output/、release/、.tools/ 或编译缓存；安装包单独作为 Release 附件。当前工作目录尚未初始化 Git，不要覆盖远程已有 LICENSE。
2. 审查源码与安装包对应后，以 `v0.1.0` 为标签创建 Release。发布说明可使用 RELEASE_NOTES.md；此版本保持实验性质，不宣称全面兼容。
3. 上传 `output/maxhoov.VirtualBoy_0.1.0_2026-09-22.zip`。ZIP 根目录直接包含 Cores、Platforms、Assets、Documents，不要再套一层 release 目录。不要上传游戏 ROM。
4. 发布前运行 `npx --yes openfpga-validator@latest check "output/maxhoov.VirtualBoy_0.1.0_2026-09-22.zip"`，处理报错并审查警告；本地 `tests/check_package.ps1` 不替代该工具。
5. 在 https://github.com/openfpga-library/analogue-pocket 的 Issues → New issue → Add Core 按表单申请收录，提供公开仓库及发行信息。核心标识为 `maxhoov.VirtualBoy`，平台为 `virtualboy`，分类为 Console。
6. 收录后通过 Pocket Sync 刷新目录检查实际安装与版本检测。在此之前，可让测试者手动把 ZIP 拖入 Pocket Sync。

后续更新保持核心标识不变，更新 core.json 的版本和发布日期，发布对应源码标签及新的安装 ZIP。只更改文档和元数据可用 `./build.ps1 -PackageOnly`；修改 RTL 必须完整编译并通过时序检查。

参考：https://github.com/neil-morrison44/pocket-sync#faqs
