# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
