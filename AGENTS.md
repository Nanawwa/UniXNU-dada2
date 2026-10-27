# Agent instructions

This repository owns the dada board configuration, device tree, firmware
selection, memory and storage policy, and packaging. Shared SM8750 resources
and platform operations belong to `UniXNU-sm8750-common`. The documentation
site, component catalog and common build tools belong to `UniXNU`.

Read the following before editing:

| Task | Required reading |
| --- | --- |
| Every port | [Porting](https://unixnu.com/porting/), [repository format](https://unixnu.com/porting/device-repository), [component catalog](https://unixnu.com/reference/components) |
| Hardware | [Device tree](https://unixnu.com/porting/device-tree), [matching](https://unixnu.com/drivers/device-tree-matching), SM8750 DTSI and `soc.toml` |
| Components | Selected component README, catalog metadata, build interface, relevant source |
| Kernel | Selected OS profile, XNU source, [patch reference](https://unixnu.com/xnu/source-and-patch-reference), ordered patch series |
| Images | [Prelink](https://unixnu.com/concepts/prelink), [payload](https://unixnu.com/concepts/payload), [UEFI firmware](https://unixnu.com/porting/uefi-firmware) |
| Verification | [Building](https://unixnu.com/building), [bring-up](https://unixnu.com/porting/bring-up), [log capture](https://unixnu.com/porting/log-capture) |
| Migration | [Migration](https://unixnu.com/porting/migration) |

Search UniXNU's `components.toml` and read existing implementations before
adding a capability. Use canonical component IDs in directories, selections,
build commands and documentation; keep the source filenames, runtime classes,
bundle IDs and symbols the catalog records as `runtime_identifiers`.

The board DTS is `dts/dada.dts`; it includes the SM8750 SoC DTSI and carries
the board memory, reservations and ADT exports. The UEFI firmware lives in
`../uefi-dada` (a Mu-Silicium fork); `board.toml [firmware]` points at its DSC
and FD.

Run from the UniXNU checkout:

```sh
./unixnu defconfig dada_defconfig -D ../UniXNU-dada
./unixnu status --json -D ../UniXNU-dada
./unixnu tree -D ../UniXNU-dada
./unixnu build kernel -D ../UniXNU-dada
```

Use the README for firmware and payload inputs. Run the existing checks for the
changed area, including `scripts/check-dada.py` and
`scripts/tests/check-kernel-archives.py`. Report commands, outputs, missing
inputs and hardware observations separately. Record device boot, storage,
display, input and GPU checkpoints.

## Porting record

Read the device's `porting.toml` and the
[record guide](https://unixnu.com/porting/records) before implementation.
For storage, also read the [UFS guide](https://unixnu.com/porting/ufs).
Update each affected area's findings or evidence with its code change.
The documentation site renders this same record. Follow its schema and
completion levels for both maintainer and agent work.