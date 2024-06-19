# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2024-06-19

### Added

- Support for `telemetry` v1.0 [@JVMartyns](https://github.com/JVMartyns).

## [1.4.0] - 2023-10-27

### Added

- Support for `:keep` and `:drop` options for filtering events by [@jfpedroza](https://github.com/jfpedroza).

## [1.3.0] - 2022-11-26

### Added

- Support calculating metrics using both `measurements` and `metadata`, as introduced in `telemetry_metrics` [v0.6.0](https://github.com/beam-telemetry/telemetry_metrics/blob/main/CHANGELOG.md#060), by [@quinlanjager](https://github.com/quinlanjager).

## [1.2.1] - 2021-12-06

### Fixed

- Improved performance of handling events by [@nallwhy](https://github.com/nallwhy).

## [1.2.0] - 2021-09-30

### Added

- Added support for telemetry 1.0.

## [1.1.0] - 2021-01-21

### Added

- Added support for Appsignal 2.0.

## [1.0.0] - 2020-05-27

### Changed

- `TelemetryMetricsAppsignal` is now implemented as a `GenServer` and performs cleanup
  of telemetry handlers upon termination (kudos to @bradleygolden).

### Fixed

- Marked `jason` as an optional dependency - it's only required by `appsignal` when testing.
- Suppressed warning when measurement was missing from an event.

## [0.1.1] - 2020-05-17

### Fixed

- Fixed using `tag_values` to generate tags from metadata.

## [0.1.0] - 2020-04-07

### Added

- Implemented reporting all `Telemetry.Metrics` measurements to AppSignal.
