<!--
Next release template. Before publishing 0.1.1:
  1. Fill in the bullets below (delete any subsection you don't use).
  2. Bump `version: 0.1.1` in pubspec.yaml to match this header.
  3. Commit, then tag `v0.1.1` and push the tag to publish.
-->
## 0.1.1

### Added

- _New features go here._

### Changed

- _Behavior changes / improvements go here._

### Fixed

- _Bug fixes go here._

## 0.1.0

- Initial release.
- Export logs to an OpenTelemetry collector over OTLP/HTTP (JSON).
- `OtelLogExporter` with `package:logging` integration via `attachToLogger`.
- `OtelConfig` configuration, including `OtelConfig.fromEnvironment`.
- OTLP attribute formatting, severity mapping, and payload building.
- Distributed-tracing correlation via `trace_id` / `span_id` / `trace_flags`.
- Automatic `exception.*` attributes for logged errors.
- Graceful, non-throwing error handling with an `onError` callback.
