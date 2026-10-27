# Reproduction and recorded validation

The included Objective-C programs are the original local reproduction/audit sources. They do not install hooks or change system files. **A reproduction of the unfixed fragment/MSAA path previously produced GPU errors; do not run GPU stress/reproducers on an unsaved production desktop without accounting for that.** No automatic GPU test workflow is supplied.

Build the minimal reproduction on the target Mac using Apple's command-line tools:

```sh
clang -fobjc-arc -O2 -framework Foundation -framework Metal minimal-msaa.m -o minimal-msaa
./minimal-msaa hardware
./minimal-msaa compute
./minimal-msaa compute-serial
./minimal-msaa fragment
```

It enumerates both GPUs by default and checks readback values. `D500_MIN_DEVICE` restricts it to one runtime registry ID. IDs in the recorded JSON are transient device identifiers, not hardware serial numbers. The post-boot run used no environment overrides; inspect `badCount`, command-buffer status and errors rather than checking process exit status alone.

The broader audit sources are `deep-metal-audit.m` and `deep-coreimage-audit.m`. The former covers non-square RGBA/BGRA textures, storage modes, sample counts, resolves and integer compute validation; the latter compares six Core Image operations on each GPU with CPU rendering. Source is provided so reviewers can inspect exactly what was tested. For the recorded runs, the Metal matrix was repeated 20 times (34 cases per iteration), and all 12 Core Image comparisons were within 1/255.

## Signature and boot distinction

Local signature verification alone did not establish protected-process compatibility. The failed ad-hoc candidate passed weaker local checks but was rejected by WindowServer. The successful candidate retained official signatures and also passed a separate platform-process Library Validation reproduction before normal boot was attempted. This repository records that outcome, not a general guarantee about unsigned modifications.

## Test interpretation

- GPU identifiers are runtime labels; two GPUs do not imply that a single app uses both concurrently.
- The synthetic H.264/VideoToolbox flow selected software encoding/decoding. It cannot demonstrate hardware codec acceleration.
- Short zero-error runs do not establish sleep/wake support, all screen setups, prolonged stability or an absence of regressions in unrelated applications.
- The selected public JSON excludes full process lists, user paths, display identifiers, snapshot IDs and application logs. No private crash reports or browser profile dumps are published.
- Installer simulation during the original investigation tested apply, rollback and injected snapshot failure in a temporary filesystem; it was not another real system install. The working driver installation was unchanged during publication.
