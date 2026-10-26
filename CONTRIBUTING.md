# Contributing

Keep authored RTL, firmware, host software, analysis, and documentation together in reviewable changes. Preserve the paths used by the Tcl and firmware scripts unless their consumers are updated in the same change.

- Run the relevant RTL regression for datapath or controller changes.
- Run firmware host tests for firmware or shared protocol changes.
- Run host tests and startup smoke checks for UI, protocol, or decoder changes.
- Run MATLAB analysis tests for analysis and capture-decoder changes.
- Rebuild and review timing, CDC, and DRC when changing integrated hardware.
- Record tool versions and distinguish simulation, estimates, host tests, and physical measurements.

The `.gitignore` uses an allowlist. When adding a source directory, explicitly include it and inspect `git status` before committing. Never commit credentials, installed dependencies, generated projects, bitstreams, ELFs, caches, host binaries, or raw session captures. Distribute reviewed binary packages separately with matching hashes and provenance.

Changes to the shared protocol must update firmware and host together. Document test outcomes and limitations in the pull request; do not report board acceptance without recorded board evidence.
