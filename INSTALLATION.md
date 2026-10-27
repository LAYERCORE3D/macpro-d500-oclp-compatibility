# Exact installation source — limited reproduction

This is the narrow installer used in the successful single-machine trial, published for review. It is not integrated into official OCLP. **Do not install it merely because you have an AMD GPU.** The recorded target was MacPro6,1 / dual D500 / Sequoia 15.8.1 build 24H32, already root-patched with OCLP. The installer enforces the model, OS, build, tested disk layout and original shim hash, but does not independently enforce every aspect of the GPU/OCLP configuration.

## Obtain the official payload

1. Obtain `Universal-Binaries.dmg` from [Dortania PatcherSupportPkg 2.0.5](https://github.com/dortania/PatcherSupportPkg/releases/tag/2.0.5).
2. Verify its SHA-256 is `1c290781bc726759ff37a110ffcb7182a6c6fd3d8ebce112d134d482c8de52a3`.
3. Mount it read-only and locate the complete `AMDMTLBronzeDriver.bundle` in the `12.5-GCN-SKL-24` variant. Preserve all files and signatures. Do not take the similarly named `12.5-24` bundle or the Git source tree's ad-hoc-signed build inputs.
4. Copy that complete bundle next to `install.py` and `manifest.json`, using a method that preserves the bundle. The installer checks the exact file set and hashes before accepting it. No downloader or automatic system modification is included.

The official distributed bundle had a nested resource-seal caveat. Both executable signatures were verified independently using the Dortania root anchor and `--ignore-resources`; protected-process loading and later normal boot were separately tested. The installer preserves the exact release bytes instead of attempting to repair the seal by re-signing. This deserves upstream packaging review.

## Review before execution

`/usr/bin/python3 install.py` performs the default read-only preflight. It should refuse if the system shim is already the candidate or otherwise differs from the original tested hash. **Do not relax that check to reinstall over a different driver or macOS update.**

Only explicit `--apply` or `--rollback` writes the system. The `.command` wrappers run the corresponding option with local administrator authentication and wait before closing. When obtained through a GitHub browser upload/archive, executable bits may not be retained; source can be inspected/run from Terminal instead. Never paste an administrator password into GitHub or a chat.

The installer stages the complete bundle, validates it, preserves the prior bundle, selects a new APFS snapshot with `bless`, records its state under `/Library/Application Support/D500Official205/`, and does not reboot automatically. A successful preparation message does not prove the next boot will succeed.

## Recovery

Keep the original installation directory and verified backup. `Revertir candidato oficial.command`, or `sudo /usr/bin/python3 install.py --rollback`, uses that backup/state and refuses unknown bundle contents. If graphical startup fails, a supported safe-boot or external recovery route may be needed. Do not delete backup/state files. The earlier failed experiment's rollback package is different; do not confuse it with this official-payload installer.

No new system installation is performed by publishing this repository. Security/OS updates or OCLP root repatching can replace these files; the exact pinned result must be reassessed rather than assuming it persists.
