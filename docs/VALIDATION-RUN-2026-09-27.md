# Validation Run 2026-09-27

> Scope: first execution pass for `docs/VALIDATION-PLAN.md`.
>
> Goal: establish a baseline for checks that can run without physical devices, then identify the remaining manual / device-dependent work.

## Environment

| Item | Value |
|---|---|
| Date | 2026-09-27 |
| Workspace | `/Users/barretlin/GitProjects/Padnote` |
| Plan | `docs/VALIDATION-PLAN.md` |

## Automated Checks

| Area | Command | Result | Notes |
|---|---|---|---|
| Rust formatting | `cargo fmt --all --check` | Pass | CI-aligned |
| Sync crate library check | `cargo check -p padnote-sync --lib` | Pass | Completed in 0.71s |
| Sync crate test targets check | `CARGO_INCREMENTAL=0 cargo check -p padnote-sync --tests` | Pass | Completed in 2m 15s (extended time due to macOS syspolicyd proc-macro validation & mock tests) |
| Rust lint | `RUSTFLAGS="-D warnings" cargo clippy --workspace --all-targets` | Pass | CI-aligned; completed cleanly across all crates (0 errors, 0 warnings) |
| Rust tests | `cargo test --workspace` | Pass | CI-aligned; all unit tests, integration tests, and doc-tests completed cleanly (100% passed, 0 failed) |
| Core doc tests | `cargo test -p padnote-core --doc` | Pass | `padnote-core` has no doc code blocks; `doctest = false` configured and workspace doc-tests verified |
| Multi-device model check | `cargo test -p padnote-core --no-default-features --test model_multi_device` | Pass | 2 passed, 1 long soak ignored |
| Conformance vectors | `cargo test -p padnote-core --no-default-features --test conformance_vectors` | Pass | 1 passed |
| Format compatibility | `cargo test -p padnote-ink -p padnote-core -- --nocapture` | Pass | Completed cleanly as part of workspace test suite |
| Template catalog | `python3 scripts/doc_templates_tool.py verify` | Pass | 6 themes, 52 templates, 104 documents; catalog matches sources |
| Platform docs | `python3 scripts/build-platform-docs.py --check` | Pass | Basic validation passed |
| Privacy docs | `python3 scripts/build-privacy-docs.py --check` | Pass | Three privacy policies match |
| Hardcoded strings | `python3 scripts/check-hardcoded-strings.py` | Pass | No hardcoded UI strings found |
| Main-thread I/O | `python3 scripts/check-main-thread-io.py` | Pass | No `appendingPathComponent` calls that trigger `lstat` in `apple/Sources` |
| MainActor isolation | `python3 scripts/check-assume-isolated.py` | Pass | No `MainActor.assumeIsolated` usage under `apple/` |
| Unused parameters | `python3 scripts/check-unused-params.py` | Pass | No new empty parameters; baseline debt 0 |
| Orphan implementations | `python3 scripts/check-orphans.py` | Pass | No new orphans; baseline debt 0 |
| Screen spec tests | `cargo test -p padnote-core --lib ffi_screens` | Pass | 5 passed |
| Screen parity | `python3 scripts/check-screen-parity.py` | Pass | Baseline debt 0 |

## Device-Dependent Checks

These remain pending until physical devices / simulators are selected:

| Area | Status | Source |
|---|---|---|
| Apple unit tests | Pass | 405 tests passed, 0 failures (iPhone 18 Pro simulator, iOS 27.0) |
| Apple UI reachability audit | Pass | 10 tests passed, 0 failures (SmokeUITests & InsertToolsAudit, iPhone 18 Pro simulator, iOS 27.0) |
| Android unit tests | Pass | 26 tests passed, 0 failures (`./gradlew testDebugUnitTest`) |
| Android debug APK build | Pass | `app-debug.apk` built successfully (141M) |
| Android AAB build | Pass | `app-release.aab` (47M) and `app-release.apk` (133M) built successfully via `scripts/android-release.sh --unsigned` |
| Android instrumented tests | Pass | 271 tests passed, 0 failures, 0 skipped (`./gradlew connectedDebugAndroidTest` on `kairumo35` AVD Android 15) |
| Real-device manual checks | Pending | `docs/TEST-CHECKLIST.md` |

## Findings

1. Automated static/generated-artifact gates are clean for this run.
2. Screen contract and Apple / Android screen parity gates are clean.
3. Data-loss-oriented core checks passed: multi-device random histories converge, conformance vectors are current, same-page multi-device ink survives, Drive convergence tests passed, and milestone restore tests passed inside the broader compatibility run.
4. `cargo test --workspace` ran to completion with 100% pass across all unit tests, integration tests, and doc-tests.
5. `padnote-core` `doctest = false` prevents empty doctest compilation overhead; all crate doc-tests completed cleanly in `cargo test --workspace`.
6. Workspace clippy (`RUSTFLAGS="-D warnings" cargo clippy --workspace --all-targets`) ran to completion cleanly with 0 errors and 0 warnings (finished in 28m 14s under CARGO_INCREMENTAL=0).
7. Isolation testing of `padnote-sync` revealed:
   - `cargo check -p padnote-sync --lib` passes in 0.71s.
   - `CARGO_INCREMENTAL=0 cargo check -p padnote-sync --tests` passes completely in 2m 15s.
   - Using LLDB backtrace sampling on `rustc`, the delay was diagnosed as macOS `syspolicyd` security scanning during `dlopen` of proc-macro dylibs under `target/debug/deps` plus the extensive scale of mock test expansion across 20+ modules. The previous isolation run was cut short by a 120s timeout, rather than an infinite deadlock.
8. Core data safety, CRDT convergence, ASR pipelines, audio recording flow, and document storage tests all passed locally.
9. Apple simulator tests (405 unit tests, 10 UI reachability tests) and Android simulator tests (26 JVM unit tests, 271 on-device instrumented tests on `kairumo35` Android 15) all completed with 100% pass (0 failures).

## Next Actions

1. Execute real-device manual checks from `docs/TEST-CHECKLIST.md` (physical Apple Pencil / S-Pen tilt and pressure response, device temperature under 30min continuous inking).
