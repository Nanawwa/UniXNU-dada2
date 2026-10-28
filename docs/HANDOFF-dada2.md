# dada2 引导链交接（Redmi K80 Pro / UniXNU）

更新时间：2026-10-28 夜
适用对象：接手继续做 bring-up 的 harness / 人。本文自包含，不需要上一轮对话。

---

## 1. 目标与边界

把 UniXNU（UEFI 引导层 + 移植的 4K XNU 内核）在 Redmi K80 Pro 上跑起来，最终目标是"补全功能"（显示→触摸→Wi-Fi→音频→Metal）。

- 基线 OS 是 **iPadOS 17.7.11 (21H461, iPad7,1/j120ap) 的 XNU + kernelcache**，不是完整系统；界面若跑到 userland 会是平板布局。换 iPhone 固件是独立里程碑，不是当前阻塞项。
- 无 Secure Enclave → Apple ID/App Store/FairPlay 永久不可用（硬件限制）。
- **红线**：只用 `fastboot boot`（RAM 引导），不写任何分区、不动 slot、不刷 boot_a/boot_b。手机重启即回 Android。任何擦除/GPT/分区写操作都必须先拿到用户明确同意。

## 2. 硬件事实（已核实）

| 项 | 值 |
|---|---|
| 产品名 | `miro`（`ro.product.model` = 24122RKC7C，市场名 REDMI K80 Pro） |
| SoC | SM8750（"sun"，Snapdragon 8 Elite），8 核 2 簇（0x10000/0x10100 为 prime） |
| BL | 已解锁（`fastboot getvar unlocked` → `yes`；Android 里 `ro.boot.flash.locked=1` 不可信） |
| 当前槽 | `b` |
| 面板 | 原生 **1440×3200**（HyperOS 默认跑 1080×2400）；`splash_region` = 0xfc800000 + 0x2b00000 |
| USB 序列号 | 4a06a58a |
| 分区 | 6 LUN / 140 分区 / 4KB 扇区；**无 linux/esp 分区**（这是与 dada 参考机的关键差异） |
| 全量备份 | 笔记本 `D:\抢救文件\Desktop\K80pBackup\GeekFlashTool_Readback_20260709202628797\`（含 abl_a.img、boot_a.img、vendor_boot_a.img、dtbo_a.img 等） |

## 3. 环境

- 构建机：Debian mini，SSH `root@100.69.85.112`（key 已部署到本笔记本；换机器需用户提供凭据）。
- 主仓库 `/root/k80pro-port/UniXNU`（UniXNU 上游 + 本地改动）
- 设备仓库 `/root/k80pro-port/UniXNU-dada2`（GitHub `Nanawwa/UniXNU-dada2`，分支 `k80pro-port`）
- SoC 共享仓库 `/root/k80pro-port/UniXNU-sm8750-common`
- UEFI 树 `/root/k80pro-port/uefi-dada`（GitHub `7Night-kqx/uefi-dada`，Mu-Silicium fork）
- 工具链 `/opt/unixnu-linux`；构建产物在 `UniXNU/out/dada2/ipados-17.7.11-21H461/dada2/`
- 日志 `/root/k80pro-port/*.log`；构建日志 `.../dada2/logs/`
- 本笔记本镜像目录 `D:\抢救文件\Desktop\dada2-images\`（boot.img / kernel.macho / SILICIUM_UEFI.fd / README.txt）

## 4. 构建流水线（全部已跑通）

在 `/root/k80pro-port/UniXNU` 下：

```sh
# 1) 内核（需要 kernelcache，已在 out/ipsw/21H461/kernelcache.decompressed）
UNIXNU_KERNELCACHE=out/ipsw/21H461/kernelcache.decompressed \
  ./unixnu build kernel -D ../UniXNU-dada2 -j4

# 2) payload（平台种子不落盘，每次随机）
./unixnu build payload -D ../UniXNU-dada2 --unique-chip-id $(openssl rand -hex 8)

# 3) UEFI 固件
./unixnu build firmware -D ../UniXNU-dada2 --uefi ../uefi-dada

# 4) Android boot 镜像（v4 = BootShim + FD + payload 作 ramdisk + 追加 DTB）
./unixnu bootimg -D ../UniXNU-dada2 --uefi ../uefi-dada \
  --dtb /root/k80pro-port/uefi-dada/Resources/DTBs/dada2.dtb
```

产物：
- `out/dada2/ipados-17.7.11-21H461/dada2/kernel/kernel.macho`（51,150,848 B，sha256 `e62cedad…`）
- `out/.../dada2/payload/payload.img`（192 MiB FAT，卷标 DADA2ESP）
- `out/.../dada2/boot/boot.img`（~203 MB，header v4）
- `uefi-dada/Build/dada2Pkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd`（3 MiB）

实机测试循环（笔记本，platform-tools 在 `C:\Users\lteyo\AppData\Local\Android\Sdk\platform-tools`）：

```sh
adb reboot bootloader
fastboot boot D:\抢救文件\Desktop\dada2-images\boot.img
# 卡死时：长按电源键 10 秒强制重启回 Android
```

## 5. 已达成（实机验证）

1. `boot.img` 被 ABL 接受并引导（`fastboot boot` OKAY）。
2. **显示链路正常**：UEFI 菜单、Apple 徽标、"UniXNU version 0.1.0" 都清晰不花屏（修法见 6.1）。
3. **UniXNU 菜单应用能启动并绘制**：四个按钮（Return to firmware / Restart / Power off / Tools），30 秒倒计时，底部滚 USB PHY 日志。
4. 超时后按默认项返回固件 → BDS 尝试 USB → 落到 "Failed to Find an Operating System!"（这是当前终点，符合预期行为）。

## 6. 已修复的关键问题（按发现顺序）

### 6.1 屏幕文字拉成竖条纹
`dada2.dsc` 里 `PcdFrameBufferWidth/Height` 原样抄了 dada 的 1200×2670。K80 Pro 是 1440×3200 → GOP 步长错位。
**已改**：`uefi-dada/Platforms/Xiaomi/dada2Pkg/dada2.dsc` → 1440 / 3200。

### 6.2 固件内嵌的是小米 15 的 DTB
FDF 把 `FdtBlob/sm8750-xiaomi-dada.dtb`（"Haotian"，board-id 0x40008）作为内嵌树 → UEFI 全程用别人的硬件描述（RPMh 报 6 条 `Rpmh protocol is not initialized: Not Found`）。
**已改**：换成 miro 真机 FDT——从运行中的 Android `adb exec-out su -c "cat /sys/firmware/fdt"` 导出（906,082 B，model = "Qualcomm Technologies, Inc. **Miro** based on SM8750"），存为 `FdtBlob/sm8750-xiaomi-miro.dtb`，FDF 引用改掉；同一份也放在 `Resources/DTBs/dada2.dtb` 供 bootimg 使用。

### 6.3 dada2Pkg 平台包缺失
uefi-dada 只有 `dadaPkg`。做法：复制 `dadaPkg` → `dada2Pkg`，改名 `.dsc/.fdf`、`PLATFORM_NAME=dada2`、所有 `dadaPkg/` 路径、`Include/*.inc`；新增 `Resources/Configs/dada2.toml`（FD base 0xA7100000 / size 0x300000，boot_shim requires_kernel_header，header_version 4）。
三个 mu-silicium 补丁（`UniXNU-dada2/docs/patches/`）需要手工适配：`unixnu-components` 可直接套；`unixnu-ramdisk` 因上下文漂移改为手工加入 `UniXNURamDiskDxe.inf` 两行（dsc 组件表 + fdf INF）；`bootshim-header-size` 已应用到 `BootShim/BootShim.S`（`FD_SIZE + (_Payload - _Head)`）。
另外 `MemoryMapLib.c` 补了 UFS 寄存器窗口 `0x01D80000 + 0x28000`（原缺，preflight 会警告）。

### 6.4 内核/驱动代码里的构建链 bug（已修，在 UniXNU-dada2 与主仓库）
- `build-dada2-platform-power.py`：`DadaPlatformPower22` 拼写 → `DadaPlatformPower2`
- `build-dada2-boot-log.py` / `build-boot-progress.py`：源码路径应为 `kits/dada2/`（树里包模块的挂载点），不是 `kits/dada/` 或 `package/`
- `scripts/build-xnu-4k-baseline.sh`（设备仓库副本）：`CONFIG_XNU_DADA2_BOOT_LOG=1` 时 `-force_load libDadaBootLog.a`，否则 `load_init_program` 里的 `boot_log_start` 链接失败
- `check-dada2.py`：改为期望 dada2Pkg/dada2.toml
- `dts/dada2.dts`：引用的 `&gic`/`&ufs` 标签在 sm8750.dtsi 里才有（原来写 `&{/timer}`、`&intc` 不存在）；sm8750.dtsi 的 8 个 cpu 节点原来全是 `disabled`，已改 `okay`
- 主仓库 `scripts/unixnu/kernel.py`：`build_archives` 现在导出 `UNIXNU_PRELINK_SLIDE`（上游 PR #124）
- 补丁链修复：`zzzzzzzzzzz-dada-owner-cache-root-hex.patch` 的 hunk 曾把 `#if XNU_BOOT_PROGRESS` 行删掉（导致 `#else without #if`），已重写；`lib-list` 的 hunk 同步修正。已用 87 项 `check-kernel-archives.py` 与 kern_exit.c 的 cpp 检查验证。

### 6.5 构建链的坑（务必记住）
- **不要在 `tree/.cache/xnu-work` 里 `git stash`**：会把 75 个补丁卷走而 `xnu-inputs.json` 印记不失效 → 裸源码编译。修复=删 `xnu-work` + `xnu-inputs.json` 让 prepare 重建。
- mini 网络静默丢 `raw.githubusercontent.com`：`prepare-xnu-source.py`（设备仓库副本）已改为 **blob API 优先**。
- 引导需要 `UNIXNU_KERNELCACHE`；`startup.o.json` 存在但 `link.filelist` 缺失时，删掉 `startup.o.json` 强制重跑 bootstrap。

## 7. 当前阻塞（下一轮从这开始）

### 现象
菜单显示 **"built-in configuration"**，只有 4 个 action 按钮，**没有 payload 里的 `xnu` 启动项**。即 payload 卷（DADA2ESP：`unixnu.toml` + `Payloads/kernel.macho` + `kernel.macho.adt`）没有被挂载出来。30 秒后默认项 Return to firmware → BDS 报 `Error: Image at 000CFB3000 start failed: Not Found`，接着尝试 USB 引导，最后 no-OS 关机。

### 已确认的机制
`UniXNURamDiskDxe` 的职责：把 `/chosen/linux,initrd-start/end` 指向的内存发布成只读 BlockIo → FAT 驱动绑定 → 应用扫到 `EFI/UniXNU/unixnu.toml`。

它原本只认一个 HOB（GUID `DAEE82E6-8090-4E72-BFB9-78C13CD4E359`，内容是 x0=FDT 指针）。**整棵 uefi-dada 树里没有任何代码创建这个 HOB**（全文件字节扫描 0 命中）。参考机 dada 不用 ramdisk 路径（它把 payload 写进真实 UFS ESP），K80 Pro 没有 ESP 分区。

### 已做的三次尝试
1. **内存扫描（不校验）**：`Data abort: Synchronous external abort`（`CpuExceptionHandlerLib.c(439)` assert）。
2. **内存扫描（描述符+FAT 校验）**：仍崩（同一 assert）。原因未最终确定，怀疑读到了描述符里标成可用但实际不可访问的页。
3. **Handoff 页（当前版本，不扫描）**：
   - `BootShim.S`：`movz/movk` 构造 `0xA75FF000`，`str x0` 存 FDT 指针（不能用 `ldr =`，字面量池会破坏 `_Payload` 对齐校验）
   - `dada2.dsc`：`PcdUniXNURamDiskHandoffAddress|0xA75FF000`
   - `MemoryMapLib.c`：从 `UEFI_FD_Reserved` 尾部切一页，登记 `UNIXNU_HANDOFF` 保留页（不能放 0xA7000000，和 `FD_Reserved` 重叠）
   - 驱动：HOB 缺失时读 handoff 页 → 校验 FDT 头 → 读 `/chosen` initrd 范围 → 校验范围在有效内存描述符内 → 校验起始处是 FAT BPB（512 字节扇区、0x55AA）→ 发布
   - 现状：**不崩了**，但菜单仍是 built-in。

### 关键诊断（尚未被看到）
在应用的 fallback 标签里加了一行诊断（`Config.c`）：
```
built-in · v<卷数> h<handoff值> t<FDT有效> f<FAT有效> i<initrd起址>+<大小> p<驱动是否发布>
```
驱动同时把同样的五个值写进 handoff 页 +0x10（`PublishVerdict`）。
**下一轮第一件事：让用户拍菜单页顶部，读出这行值。** 最近一次照片没有拍到该行（菜单被裁切），所以还不知道 v/t/f/i/p 的实际取值。

### 最强假设（决定后续方向）
ABL 传进 x0 的 FDT 就是我们追加的 `dada2.dtb`，而它来自**运行中的 Android 的 `/sys/firmware/fdt`**——其中 `/chosen/linux,initrd-start/end` 指的是 **Android 自己的 initrd**，不是我们 boot.img 里的 payload ESP（192MB ramdisk 被 ABL 放在某个未知地址，且 v4 header 不带地址字段）。所以 FAT 校验必然失败（或指向已失效内存，这也解释了前两次崩溃）。
→ 若诊断显示 `t=1, f=0, i=<某个非 payload 地址>`，假设成立。

## 8. 下一轮的候选方案（按推荐度）

**A. 把 payload 并进内核 blob，由 Shim 自己记地址（推荐，最确定）**
现在 bootimg 把 `shim+FD` 作为 kernel（gzip）、payload 作为 ramdisk。改成：`shim + FD + ESP` 一起作为 kernel，Shim 在把 FD 复制到 0xA7100000 后，把 **ESP 在解压镜像中的地址**（`_Payload + FD_SIZE`）和长度（bootimg 生成的尾部小 header）写进 handoff 页；`RamDiskDxe` 直接发布该区间（跳过 FDT/initrd 逻辑）。
注意：ESP 建议从 192MiB 缩到 ~64MiB（当前只用了 ~52MB，`board.toml [payload] size_mib`），kernel 总量 ~67MB，ABL 的 kernel 上限未知，先小后大验证。

**B. 修 Boot#### 的 device path**
`Error: Image at 000CFB3000 start failed: Not Found` 可能是 `UniXNUDxe` 注册的 Boot####（`EfiInitializeFwVolDevicepathNode` + `PcdUniXNUApplicationFile` GUID）解析失败——应用虽然在跑（很可能是 MsBootPolicy 的 FV 扫描兜底），但 BDS 之后仍会去启动那条坏项。若确认，修 device path 或干脆去掉 registrar 只留 FV 扫描。

**C. 让 payload 走 UFS**
写一个小的 scratch 文件到 userdata 或临时分区——会写用户数据，**需要用户明确同意**，放最后。

## 9. mini 上未提交的改动（接手时必须知道）

`git -C /root/k80pro-port/UniXNU status`：
```
M package/UniXNUPkg/Driver/UniXNURamDiskDxe/UniXNURamDiskDxe.c     # handoff 页 + 校验 + verdict
M package/UniXNUPkg/Driver/UniXNURamDiskDxe/UniXNURamDiskDxe.inf   # 加 UniXNUPkg.dec / PCD
M package/UniXNUPkg/Library/UniXNULib/Config.c                     # fallback 诊断标签
M package/UniXNUPkg/Library/UniXNULib/UniXNULib.inf                # PCD
M package/UniXNUPkg/UniXNUPkg.dec                                  # PcdUniXNURamDiskHandoffAddress
```
`git -C /root/k80pro-port/uefi-dada status`：
```
M  BootShim/BootShim.S
?? Platforms/Xiaomi/dada2Pkg/            # 新建平台包（dsc/fdf/dec/Include/Library/FdtBlob/Drivers/DeviceBuild.py）
?? Resources/Configs/dada2.toml
?? Resources/DTBs/dada2.dtb
```
`git -C /root/k80pro-port/UniXNU-dada2 status`：`M board.toml`（`[payload] timeout = 30`，为拍照方便；正常用建议改回 3）。

另有本地临时脚本（未入库）：无。Windows 侧 `push-bundles/`、`test-patch-chain.py` 等为一次性调试产物，可忽略。

## 10. GitHub 状态

- `Nanawwa/UniXNU-dada2` 分支 `k80pro-port`：已推（tip `7c52d7a`，含 6.4 中所有设备仓库修复）
- `UniXNU/UniXNU` **PR #124**：`kernel: hand the board prelink slide to the archive builders`（1 文件 +5 行，MERGEABLE/CLEAN，等上游 review）
- fork `Nanawwa/UniXNU`：分支 `slide-fix` 即 PR 分支
- 推送需代理：`git -c http.proxy=http://127.0.0.1:7890 push …`（本笔记本 7890 端口）

## 11. 复现"当前状态"的最短路径

```sh
# 在 mini 上（源码已是当前状态）
cd /root/k80pro-port/UniXNU
./unixnu build firmware -D ../UniXNU-dada2 --uefi ../uefi-dada     # ~2 min
./unixnu build bootimg  -D ../UniXNU-dada2 --uefi ../uefi-dada \
  --dtb /root/k80pro-port/uefi-dada/Resources/DTBs/dada2.dtb
scp out/dada2/ipados-17.7.11-21H461/dada2/boot/boot.img  <笔记本>
# 笔记本
adb reboot bootloader && fastboot boot boot.img
```

## 12. 与用户协作的约定

- 用户会拍照发屏幕内容；主模型不能看图时可先用 `node ~/.zcode/vision-cli.mjs <图片> "问题"`。
- 卡死时提示用户长按电源键 10 秒。
- 规范：临时文件即用即删、不往仓库外乱丢；不把 root 密码写进任何文件。
- 版本选择问题（为什么是 iPadOS 而不是 iOS）：因为只有 `ipados-17.7.11-21H461` 这个 profile 是经过验证的（kernelcache 钉死、4K 补丁系列、prelink 符号），换 iPhone 固件需要重建 profile，且不解决 Secure Enclave 缺失。
