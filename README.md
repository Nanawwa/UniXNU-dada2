# UniXNU-dada2

[English](#english) | [简体中文](#简体中文)

<a id="english"></a>

## English

Device support for the **Redmi K80 Pro** (`dada2`, Qualcomm SM8750) on [UniXNU](https://github.com/UniXNU/UniXNU), which boots iPadOS on non-Apple ARM64 hardware through UEFI.

This repository is a fork of [7Night-kqx/UniXNU-dada](https://github.com/7Night-kqx/UniXNU-dada) (the Xiaomi 15 port). Both devices share the SM8750 SoC; the UFS controller, GIC-v3, 19.2 MHz timer and CPU topology addresses were verified identical against the K80 Pro stock device tree and a full-partition backup. Board-specific values that differ (panel geometry, DRAM layout, partition windows) still carry dada's conservative first-boot values and need on-device measurement before flashing.

### State

Porting status follows this repository's `porting.toml`:

| Area | State |
| --- | --- |
| Configuration, firmware, CPU, memory, storage, packaging, diagnostics | implemented (inherited from dada) |
| Display, input, GPU, power | planned |

No image from this repository has been booted on a K80 Pro. The build pipeline is unverified on hardware.

### Structure

| Path | Contents |
| --- | --- |
| `board.toml` | Device configuration, component selection, payload policy |
| `configs/dada2_defconfig` | Device kernel settings |
| `dts/dada2.dts` | Board memory, reservations, timer rate, ADT exports |
| `drivers/DadaUfs2` | SM8750 UFS transport (fork of dada's DadaUfs) |
| `drivers/DadaPlatformPower2` | Platform power (fork of dada's DadaPlatformPower) |
| `porting.toml` | Per-area status, evidence and completion criteria |
| `docs/` | Pinned values, UFS notes and main-repository patches |

### Build (Linux host)

The kernel step needs the UniXNU Linux toolchain:

```sh
git clone --recurse-submodules https://github.com/UniXNU/UniXNU
git clone https://github.com/Nanawwa/UniXNU-dada2
git clone https://github.com/IssacL04/UniXNU-sm8750-common
cd UniXNU
sudo scripts/linux/setup-toolchain.py
./unixnu defconfig dada2_defconfig -D ../UniXNU-dada2
./unixnu fetch -D ../UniXNU-dada2
./unixnu build kernel -D ../UniXNU-dada2
```

The SM8750 SoC source is resolved through `local.toml` (see `local.toml.example`) until the maintainer's repository is published; `feeds.toml` records the intended pin.

### Differences from dada

- Device identity strings (`dada2`, `xiaomi,dada2`), defconfig, DTS model, payload volume `DADA2ESP`.
- Partition table measured from a K80 Pro full readback: 6 LUNs, 140 partitions, 4 KiB sectors, no `linux` or `esp` partition. The userdata window in `board.toml` is a placeholder pending measurement on the phone.
- Splash framebuffer and DRAM regions carry dada values; the K80 Pro panel is 1440x3200 and its memory map differs. Both are first-boot TODOs.

### License

BSD-2-Clause-Patent, inherited from UniXNU and UniXNU-dada. This repository contains no Apple system files; the OS profile consumes an IPSW the user supplies.

---

<a id="简体中文"></a>

## 简体中文

**红米 K80 Pro**（代号 `dada2`，高通 SM8750）在 [UniXNU](https://github.com/UniXNU/UniXNU) 上的设备支持仓库。UniXNU 通过 UEFI 在非 Apple ARM64 硬件上启动 iPadOS。

本仓库 fork 自 [7Night-kqx/UniXNU-dada](https://github.com/7Night-kqx/UniXNU-dada)（小米 15 移植）。两台设备同用 SM8750；UFS 控制器、GIC-v3、19.2 MHz 定时器和 CPU 拓扑地址已对照 K80 Pro 原厂设备树和全量分区备份逐项核实一致。两机不同的板级值（面板参数、DRAM 布局、分区窗口）目前沿用 dada 的保守首启值，刷写前需要在真机上实测修正。

### 状态

移植状态以本仓库的 `porting.toml` 为准：

| 领域 | 状态 |
| --- | --- |
| 配置、固件、CPU、内存、存储、打包、诊断 | implemented（继承自 dada） |
| 显示、输入、GPU、电源 | planned |

本仓库没有任何镜像在 K80 Pro 真机上启动过，构建流水线未经真机验证。

### 结构

| 路径 | 内容 |
| --- | --- |
| `board.toml` | 设备配置、组件选择、payload 策略 |
| `configs/dada2_defconfig` | 设备内核配置 |
| `dts/dada2.dts` | 板级内存、保留区、定时器频率、ADT 导出 |
| `drivers/DadaUfs2` | SM8750 UFS 传输（fork 自 dada 的 DadaUfs） |
| `drivers/DadaPlatformPower2` | 平台电源（fork 自 dada 的 DadaPlatformPower） |
| `porting.toml` | 各领域状态、证据与完成条件 |
| `docs/` | 固定值记录、UFS 说明、主仓库补丁 |

### 构建（Linux 主机）

内核步骤需要 UniXNU 的 Linux 工具链：

```sh
git clone --recurse-submodules https://github.com/UniXNU/UniXNU
git clone https://github.com/Nanawwa/UniXNU-dada2
git clone https://github.com/IssacL04/UniXNU-sm8750-common
cd UniXNU
sudo scripts/linux/setup-toolchain.py
./unixnu defconfig dada2_defconfig -D ../UniXNU-dada2
./unixnu fetch -D ../UniXNU-dada2
./unixnu build kernel -D ../UniXNU-dada2
```

SM8750 SoC 源码目前通过 `local.toml` 解析（见 `local.toml.example`），等维护者仓库发布后按 `feeds.toml` 的 pin 走。

### 与 dada 的差异

- 设备身份字符串（`dada2`、`xiaomi,dada2`）、defconfig、DTS model、payload 卷 `DADA2ESP`。
- 分区表来自 K80 Pro 全量读回的实测：6 个 LUN、140 个分区、4 KiB 扇区，没有 `linux` 和 `esp` 分区。`board.toml` 里的 userdata 窗口是占位值，待真机测量后修正。
- splash 帧缓冲和 DRAM 区域沿用 dada 数值；K80 Pro 面板为 1440x3200，内存布局与 dada 不同。两项都是首启前的待办。

### 许可

BSD-2-Clause-Patent，继承自 UniXNU 与 UniXNU-dada。本仓库不含任何 Apple 系统文件；OS profile 消费的 IPSW 由使用者自行提供。
