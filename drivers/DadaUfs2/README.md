# DadaUfs

dada's UFS storage driver. Owns the SM8750 host controller bring-up, the SMMU takeover, the request
queue, GPT/window parsing and the read-only root publication.

This is the board's own driver, derived from the `ShengUfs` component (SM8550) and reduced to the
SM8750 facts:

- accepted controller names: `qcom,ufshc` and `qcom,sm8750-ufshc`; the SM8550 name is gone.
- GCC clock offsets: the SM8750 values only (`GccUfs.h`).
- root partition: the dedicated `linux` GPT entry (`kRootPartition`), not sheng's `userdata`.
- optional policy arguments use the `dada-` prefix (`dada-log`, `dada-data-persist`,
  `dada-log-reserve`); the port does not pass them.

The source file and runtime classes keep the upstream names (`DadaUfs.cpp` is the fork point;
`NativeUfs`/`NativeUfsBlock` are the IOKit personalities) so the prelink and binding records stay
comparable with the component it came from. See `docs/ufs-dada.md`.

Linked into XNU by `unixnu build kernel` through `component:DadaUfs`.