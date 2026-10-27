# MacPro6,1 dual D500 — OCLP GCN compatibility case study

**Experimental, single-machine result. Not an official OCLP release or a universal fix.**

On a Mac Pro (Late 2013) with **two AMD FirePro D500 GPUs**, macOS **Sequoia 15.8.1 (24H32)**, selecting the **unmodified, Dortania-signed `12.5-GCN-SKL-24/AMDMTLBronzeDriver.bundle` from PatcherSupportPkg 2.0.5** resolved the Electron rendering corruption reproduced in this investigation. Normal boot and the PI Dashboard interface were subsequently confirmed by the owner. The installed bundle was rechecked against the full pinned manifest on 2026-10-27.

The contribution here is the documented selection/deployment experiment, reproduction programs and evidence. **The working compatibility implementation and signed driver package are upstream Dortania/OCLP work.** This repository does not claim to have invented that implementation, add Metal 3 support, disable MSAA globally or fix every Chromium issue.

## Credits and upstream review

Thanks to the **Dortania / OpenCore Legacy Patcher and PatcherSupportPkg maintainers and contributors** for their compatibility work and signed distribution:

- [OpenCore Legacy Patcher](https://github.com/dortania/OpenCore-Legacy-Patcher)
- [PatcherSupportPkg 2.0.5 — source of the applied payload](https://github.com/dortania/PatcherSupportPkg/releases/tag/2.0.5)
- [Related rendering issue: OCLP #1145](https://github.com/dortania/OpenCore-Legacy-Patcher/issues/1145)
- [GCN/Skylake variant selector](https://github.com/dortania/OpenCore-Legacy-Patcher/blob/main/opencore_legacy_patcher/sys_patch/patchsets/hardware/base.py)
- [Legacy GCN patchset](https://github.com/dortania/OpenCore-Legacy-Patcher/blob/main/opencore_legacy_patcher/sys_patch/patchsets/hardware/graphics/amd_legacy_gcn.py)

**Review request:** could the existing texture-descriptor compatibility be backported or selected appropriately for MacPro6,1 without Skylake? The selector inspected on 2026-10-27 returns `None` when no Skylake GPU is present. This machine has two D500s and no Skylake GPU. This is evidence for review, not a request to enable the whole combined variant on every legacy GCN system. The maintainers should determine the correct implementation, signing and hardware/OS gates.

## What was applied

Only `/System/Library/Extensions/AMDMTLBronzeDriver.bundle` was replaced, as a complete bundle, with exact official release bytes. `install.py` and the two `.command` launchers are the source of the installer used for the successful installation. No kernel collection, OpenCore configuration, SIP setting or AMFI setting was changed by this installer. Existing OCLP root-patching prerequisites were already in place; this is not a stock-macOS installer.

No Apple driver binaries, full support archive, private keys, account data, crash-report dumps or old failed payloads are redistributed. Obtain the payload from the official release and preserve all signatures. The `globallyInstalled` / `bootValidated` fields in `manifest.json` are historical payload-preparation metadata, not the current installation receipt; see `verified-installation.json` for the verified deployed state.

The earlier **locally re-signed experimental candidate failed graphical boot** because WindowServer Library Validation rejected the mapped code. It was restored using safe boot. That candidate is withdrawn and is not supplied here. Keeping official signatures intact was essential to the successful trial. Do not ad-hoc re-sign the bundle or mix its executables with other variants.

## Evidence and limits

| Check | Observed result |
| --- | --- |
| Normal boot after official bundle installation | Confirmed by owner |
| Exact installed bundle hashes | Match all pinned files |
| Native hardware resolve, compute, serial compute, fragment MSAA | Pass on both D500s; zero incorrect pixels |
| Metal texture/compute matrix | 34 cases × 20 iterations; zero failed runs |
| Core Image compared with CPU | 12 comparisons; maximum channel difference 1/255 |
| Isolated Electron 42/44 rendering | 600 readback frames each with 4× MSAA; no new GPU restart in those observations |
| PI Dashboard | Full interface confirmed; GPU/Metal rendering retained in isolated tests |
| Other interfaces | iMovie interface opened and export was initiated by the owner; final exported-file visual review was not recorded |

See `postboot-native-results.json`, `metal-repetition-results.json`, `coreimage-results.json`, `verified-installation.json` and [TESTING.md](TESTING.md). These are selected, privacy-reviewed records from the investigation, not newly rerun full tests at publication time. No claim of weeks-long stability, general FPS improvement, hardware video-codec acceleration, or compatibility with all apps/GPUs/Sequoia updates is made.

Brave sluggishness, SharedImage/mailbox messages and a brief video freeze when returning from the background were also reported. Their cause was **not established**. Do not interpret this case study as fixing those symptoms. A later process-local compatibility prototype passed the tested correctness checks but took about 11.68% longer per synthetic batch than the official bundle; it was **not installed** and is not the working patch published here.

## Reproduction / deployment source

Read [INSTALLATION.md](INSTALLATION.md) before using any installer. This changes the system snapshot and can prevent graphical startup. Safe boot recovery worked once during this investigation; it is not guaranteed for every failure. Keep a separate recovery path and backup.

The archive SHA-256 and every bundle file hash are pinned in `manifest.json`. The installer defaults to a read-only check, refuses other machine/OS/build combinations and refuses a different original shim hash. It creates a verified backup and pre-change snapshot before installing, does not reboot automatically, and includes rollback source. It has not been turned into a general-purpose end-user installer.

## Español

Este repositorio documenta el cambio aplicado a un MacPro6,1 con dos D500. La solución funcional procede del paquete oficial de Dortania; aquí se comparten los scripts usados, las comprobaciones y el caso de selección para que OCLP pueda revisarlo. Solo se ha validado este equipo y esta compilación de Sequoia. No incluye controladores de Apple ni promete compatibilidad universal.

## License and preparation

The original scripts, reproduction sources and documentation supplied here are MIT licensed; see [LICENSE](LICENSE). Upstream projects and Apple components retain their own licenses. Development and documentation were AI-assisted; the records distinguish measured results, owner observations and open questions. No upstream approval or endorsement is implied.
