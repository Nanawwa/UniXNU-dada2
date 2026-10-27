# UniXNU dada

Device support for the **Xiaomi 15** (`dada`, Qualcomm SM8750 "sun") on
[UniXNU](https://github.com/UniXNU/UniXNU), which boots iOS and macOS on
non-Apple ARM64 hardware through UEFI.

The board profile selects
[UniXNU-sm8750-common](https://github.com/7Night-kqx/UniXNU-sm8750-common) and
the `ipados-17.7.11-21H461` OS profile in UniXNU. This repository owns the
board device tree, peripheral selection, firmware inputs, memory and storage
policy, and packaging.

| Repository | Contents |
| --- | --- |
| [UniXNU](https://github.com/UniXNU/UniXNU) | Build driver, component catalog, UEFI boot manager, DarwinBoot, generic drivers, kits and shared XNU patches |
| this repository | `board.toml`, `porting.toml`, DTS, defconfig, device scripts and the device package |
| `../uefi-dada` | Mu-Silicium fork with `Platforms/Xiaomi/dadaPkg` and the vendor binaries |

## Structure

| Path | Contents |
| --- | --- |
| `porting.toml` | Subsystem inputs, findings, evidence and completion criteria |
| `board.toml` | Device configuration, component selection, firmware and payload policy |
| `feeds.toml` | Pinned SM8750 SoC source |
| `configs/dada_defconfig` | Device kernel settings |
| `dts/dada.dts` | Board memory, reservations, timer rate and ADT exports |
| `patches/xnu/series` | Board patches |
| `proprietary-files.txt` | Firmware input policy |
| `package/` | Fallback UniXNU menu configuration |
| `scripts/` | Preflight, archive checks and the storage kext-binding builder |
| `docs/` | Pinned values, UFS notes and the transitional patches |

Components are named by their canonical catalog IDs. `DadaUfs` is the
board's own UFS transport: a fork of the sheng SM8550 driver reduced to the
SM8750 controller facts and the `linux` root partition; see
[docs/ufs-dada.md](docs/ufs-dada.md). The remaining checkouts under `drivers/`
and `kits/` are generic components for later subsystems and are not selected
yet.

## State

| Stage | State |
| --- | --- |
| UEFI firmware, framebuffer, menu, UFS, side buttons, UART7 | works in Mu-Silicium |
| UniXNU menu, payload volume and DarwinBoot handoff | works; the XNU console and panic screen run on the phone |
| XNU kernel entry and platform expert | mounts the root image on the linux partition and executes the first userland task; an AMFI-less entitlement guard keeps exec alive |
| UFS controller | adopts the controller, reads the GPT and publishes the linux root window; the root image mounts |
| SystemOS cryptex | the union mount composes `SystemOS` over `/`; the dyld shared cache resolves |
| Data volume | the packed `DBRDISK1` seed is published by `RamBlock` and mounted at `/private/var` |
| AMFI and PMGR | the sheng-derived PMGR instrument publishes the `ApplePMGRNub` AMFI asks for |
| **Userland** | **`launchd` (pid 1), `backboardd`, `SpringBoard`, `runningboardd`, `lsd`, `cfprefsd` and `containermanage` all run; the iOS userland starts completely** |
| Display output | **not yet: the kernel video console draws, but no `IOMobileFramebuffer` service reaches userland** |

The userland is up. A captured kernel log lists `launchd p1`, `backboardd p57`,
`SpringBoard p153`, `runningboardd p26`, `lsd p100`, `cfprefsd p90` and
`containermanage p64`, so the missing piece is the display service, not the
userland bring-up.

`docs/known-values.md` records the boot checkpoints in order, every pinned
address with its source, and the open measurements. The root image lives on the
linux partition (`/dev/block/sda36`); reads are unverified in this build.

### Boot log on the UFS disk

With `dada-log=1` the kernel writes a diagnostic log to the last 32 MiB of the
root partition (`/dev/block/sda36`), so a run can be read back from Android:

```sh
adb shell 'dd if=/dev/block/sda36 of=/data/local/tmp/log.bin bs=4096 skip=24406016 count=8192'
adb pull /data/local/tmp/log.bin
python3 scripts/read-dada-log.py log.bin --output out/log
```

The window is one header block (`DADALOG2`), 128 blocks of kernel message buffer
and a ring of 16-block text slots, written every two seconds. The header carries
`boot_id` so one boot is told from the next, and the text slots carry the
process table (`launchd`, `SpringBoard`, `backboardd`, ...). `package/BootLog.c`
is the writer, `scripts/read-dada-log.py` the reader.

## Build

The firmware must embed UniXNU, UniXNUDxe, DarwinBoot and the shared
`UniXNURamDiskDxe`, with DiskIoDxe and FAT support. Follow
[firmware integration](https://unixnu.com/porting/uefi-firmware#required-integration).

Run these commands from the UniXNU checkout:

```sh
./unixnu defconfig dada_defconfig -D ../UniXNU-dada
./unixnu fetch -D ../UniXNU-dada
./unixnu status --json -D ../UniXNU-dada
./unixnu build kernel -D ../UniXNU-dada
./unixnu build package -D ../UniXNU-dada
./unixnu build payload -D ../UniXNU-dada --unique-chip-id "$UNIXNU_UNIQUE_CHIP_ID" \
  --data-ramdisk /path/to/data.dbr --trust-cache /path/to/trustcache
./unixnu build firmware -D ../UniXNU-dada --uefi ../uefi-dada
./unixnu bootimg -D ../UniXNU-dada --uefi ../uefi-dada --dtb /path/to/firmware.dtb
```

Outputs are under `out/dada/ipados-17.7.11-21H461/dada/`. The payload step
compiles `dts/dada.dts` and generates `kernel.macho.adt`; the boot image takes
the firmware's own FDT.

The kernel step needs the pinned kernelcache and either UniXNU's Linux
toolchain or a macOS Xcode host; archives build with the recorded clang
compile records. The payload needs the platform seed; a Data seed and a trust
cache are optional inputs. None of them is stored in any repository. Save
machine-specific paths in `local.toml` in this repository (copy
`local.toml.example`) or in `unixnu.local.toml` in UniXNU.

The stock-tree changes are recorded in [docs/patches](docs/patches): Android
boot header v4 verification, the AMFI-conditional native-root guard, the
`XNU_NATIVE_UFS_ARCHIVE` override and the offline SystemOS mount gate in UniXNU, the BootShim ARM64 `image_size`,
and the DSC/FDF entries that put UniXNU, `UniXNURamDiskDxe` and DarwinBoot into
the firmware volume. This workspace has all of them applied; a fresh
`uefi-dada` checkout needs the DSC/FDF/BootShim patches, and a fresh UniXNU
checkout needs the four script patches until they are upstreamed. UniXNU's
`components.toml` also carries the `DadaUfs` catalog entry. The porting record
lists the limit.

## Host build

The Linux toolchain builds the whole pipeline on a Linux host. On 2026-10-26 a
12-core Ubuntu 24.04 host produced:

| Step | Result |
| --- | --- |
| `./unixnu build kernel -D ../UniXNU-dada` | `kernel.macho`, 50,954,240 bytes, sha256 `d47f4ac9760857ef49fa03efc47de58e157854dca23f95174d6bf56c6ecae57b`; 24 prelink components, no AMFI or PMGR |
| `./unixnu build firmware -D ../UniXNU-dada --uefi ../uefi-dada --edk2 ../uefi-dada/Mu_Basecore` | `SILICIUM_UEFI.fd`, `0x300000` bytes, sha256 `e53a559c9a9a4293a5ab72b86a4d08b3cd231e88863d5bcc198445c5a505ff28`; embeds UniXNU, UniXNUDxe, UniXNURamDiskDxe and DarwinBoot |
| `./unixnu build payload -D ../UniXNU-dada` | `payload.img`, 192 MiB `DADAESP`; kernel and ADT hashes in `payload.json` |
| `./unixnu bootimg -D ../UniXNU-dada` | `boot.img`, 203,558,912 bytes, Android header v4, sha256 `a629ae1f904fe21e051ff078b073c7e18ad45198853d20baa9a592e5a0fbd744` |

The build used the cached 21H461 kernelcache and a placeholder platform seed
from the ignored `unixnu.local.toml`. The image has not been flashed;
`fastboot boot out/dada/ipados-17.7.11-21H461/dada/boot/boot.img` is the next
device step. [docs/evidence](docs/evidence) holds the reports.

### Payload on the ESP

`/dev/block/sda35` (`by-name/esp`) carries the payload for firmware boots without an initrd. It must
be FAT32 with 4096-byte logical sectors, because the UFS LUN block size is 4096; a 512-byte-sector
payload image fails to mount with `logical sector size too small for device`. The geometry and the
deployed kernel/ADT hashes are in [docs/known-values.md](docs/known-values.md).

## Checks

```sh
python3 scripts/check-dada.py --uefi ../uefi-dada
python3 scripts/tests/check-kernel-archives.py --device .
python3 ../UniXNU/scripts/porting-record.py check --device .
```

The first is the firmware preflight: memory descriptors, vendor inputs, FD
geometry, UFS facts and kernel archive consistency. The second checks the
defconfig, archive plan, builder products and prelink-slide handling without
Xcode. The third validates `porting.toml` and its component coverage; the
`Porting record` CI job runs the same check.

## Documentation

- [Porting](https://unixnu.com/porting/)
- [Device repository specification](https://unixnu.com/porting/device-repository)
- [Device-tree specification](https://unixnu.com/porting/device-tree)
- [Component catalog](https://unixnu.com/reference/components)
- [UFS porting](https://unixnu.com/porting/ufs)
- [Migration](https://unixnu.com/porting/migration)
- [Record guide](https://unixnu.com/porting/records)

Report build results and device observations separately, with source
revisions, commands and captured output.

## License

BSD-2-Clause-Patent. See [LICENSE](LICENSE).