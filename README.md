# Virtual Boy for Analogue Pocket

基于 Jamie Blanks 的 VirtualBoy_MiSTer RTL 与 Analogue core-template 1.3.0 的实验性移植。2026-09-22 用户确认六款原始游戏的实机画面、声音和按键均正常，并在后续测试中确认菜单暂停/恢复游戏和声音正常（Pocket 固件 2.7）。长期运行、存档持久化和更多游戏兼容性仍需验证。

0.1.5-diag 接入 Pocket 菜单暂停：安全排空后停止游戏逻辑，保持画面扫描和内存刷新，菜单期间静音并屏蔽游戏按键；关闭菜单后恢复，仍按住的游戏按键需松开后重新生效。基本暂停/恢复已获实机确认；快速切换和按键释放等边界情形仍需更多测试。保留 ROM 半字顺序补偿和首次非法指令捕获，继续使用原始 ROM，不使用 halfword probe 副本。操作见 [诊断说明](DIAGNOSTIC.md)，必须同时替换位流和菜单配置。

项目主页与发行包：https://github.com/maxhoov/VirtualBoyPocket 。首个公开发行版本重置为 `0.1.0`（不带 `-diag` 后缀），沿用已实机测试的 0.1.5-diag 位流，Diagnostic version 仍为 5。下文旧版本号记录开发历史；核心仍属实验性质，诊断菜单继续保留用于反馈问题。

2026-09-22：0.1.5-diag 九组回归、Mario Clash / Wario Land / Panic Bomber 的启动及菜单暂停测试、完整编译和现有约束下的时序检查通过；最差 setup +0.221 ns、hold +0.110 ns，ALM 占用 93%。模板部分外部接口仍缺少完整板级约束，不能视为整板时序验证完成。

## 已接入

- V810 CPU、VIP、VSU；40 MHz 系统时钟，20 MHz CPU 时钟使能。
- 数据槽 0 加载最多 16 MiB ROM，32 位写入 Pocket 移动 SDRAM，支持 ROM 镜像。
- 数据槽 1 提供 8 KiB 卡带 SRAM；缺失存档初始化为 FF，由 openFPGA 管理持久化。
- 384×224、约 50.08 Hz；可选左眼红色、右眼红色、红青双眼或左眼白色。
- 48 kHz、16 位立体声 I2S；Pocket 和 Dock 手柄输入。
- ROM 下载 FIFO 溢出会阻止运行并显示错误标志。

Pocket 只有 308 个 M10K。MiSTer 的三帧显示缓存超出容量，因此使用上游已有的直接 VRAM 扫描路径。画面撕裂及双眼同步必须实机检查。

64 KiB 工作内存放在 Pocket 外部 SRAM；为满足 55 ns 器件时序，适配器会延长部分 CPU 访问等待，尚未达到原机周期精确性。卡带存档仍使用片上 RAM。

## 编译与安装

使用支持 Cyclone V 的 Quartus Prime Lite；本机工具为 25.1std。目标型号及引脚沿用模板的 5CEBA4F23C8。

```powershell
./build.ps1 -QuartusBin 'D:\Development\QuartusPrime-25.1\quartus\bin64'
```

脚本只在完整编译和时序摘要检查通过后生成 release/，并逐字节反转 RBF 位序，**不能只把 .rbf 改名为 .rbf_r**。将 release 内的目录合并到 SD 卡根目录：

```text
Cores/maxhoov.VirtualBoy/      核心与配置
Platforms/virtualboy.json      平台信息
Platforms/_images/virtualboy.bin  平台展示图
Assets/virtualboy/common/      自行放入合法取得的 .vb/.vboy/.bin
```

首次上机请备份存档；存档容量为 8192 字节，未验证非标准容量自制程序。不要在存档写入期间断电。

作者现为 `maxhoov`，平台分类固定为 `Console`。从旧包升级时，先退出核心并备份 SD 卡的 Saves、Settings 和旧核心目录；将 `Cores/PocketVB.VirtualBoy` 重命名为 `Cores/maxhoov.VirtualBoy`，再合并新包，避免同时安装两个核心。ROM 平台标识和数据槽定义未改变，不要移动原始 ROM 或删除存档；作者标识更名后的设置继承尚未实机验证，必要时重新选择显示和按键选项。当前位流及 Diagnostic version 为 0.1.5 / 5。

平台展示图为原创灰阶矢量风格 Virtual Boy 插图，不是模板示例或产品照片。源文件为 `dist/platforms/_images/virtualboy.svg`；安装包只包含 Pocket 使用的 `.bin`。按官方格式编码为 521×165、逆时针旋转 90°、每像素两字节（亮度、0）。可安装 Node.js 的 sharp 后执行 `node tools/build-platform-image.cjs` 重新生成，并检查同目录的 `virtualboy-preview.png`。格式参考：[Analogue 图形资源规范](https://www.analogue.co/developer/docs/packaging-a-core#graphical-asset-formats)。

## 控制

左方向键始终对应 VB 左方向键，Start/Select 对应原机同名键。

| 模式 | VB A/B | VB 右方向键 | VB L/R |
|---|---|---|---|
| Standard | A/B | X 上、Y 左；Dock 右摇杆四向 | L/R 或 Dock L2/R2 |
| Dual-pad | R/L | X/B/Y/A 对应上/下/左/右 | Dock L2/R2 |

Pocket 按键不足以独立映射原机所有按键；完整控制需要支持右摇杆及 L2/R2 的 Dock 手柄。映射和显示选项会持久保存。

## 验证

```powershell
./tests/run.ps1 -QuestaBin 'D:\Development\QuartusPrime-25.1\questa_fse\win64'
./tests/check_package.ps1
```

九组测试覆盖 ROM 背压/排空/重新加载、SRAM 字节寻址、按键、I2S 双声道、有效像素/同步脉冲/SKIP、独立棋盘格/活动监测、移动 SDRAM 初始化/镜像/高地址读取、外部 WRAM、乘法引擎逐周期对照、H-bias 坐标等价性、原创 V810 程序，以及 Pocket 顶层下载启动、桥接读回、菜单暂停/恢复/菜单内复位、持续扫描/刷新和按键释放保护。SDRAM 使用简化芯片模型，不替代器件模型或硬件测试。详见 [验证记录](VALIDATION.md)；首次上机按 [硬件检查清单](HARDWARE_TEST.md) 操作。

未启用 MiSTer 存档快照、作弊、TAS、SNAC、联机或休眠。未附带游戏 ROM。打包脚本仅分发专用 virtualboy.bin 平台图，不分发模板示例图像或模板作者图标。

## 来源和许可

导入的 Virtual Boy RTL 版权属于 Jamie Blanks，许可证见 LICENSE，文件内版权声明保留。平台外壳来自 Analogue 模板。

协议参考：[数据槽](https://www.analogue.co/developer/docs/core-definition-files/data-json)、[音视频接口](https://www.analogue.co/developer/docs/bus-communication)、[外部硬件](https://www.analogue.co/developer/docs/external-hardware)、[打包格式](https://www.analogue.co/developer/docs/packaging-a-core)。
