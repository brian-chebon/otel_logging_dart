## 0.1.1

### Changed

- Added pub.dev downloads, pub points, and likes badges to the README.

## 0.1.0

- Initial release.
- Export logs to an OpenTelemetry collector over OTLP/HTTP (JSON).
- `OtelLogExporter` with `package:logging` integration via `attachToLogger`.
- `OtelConfig` configuration, including `OtelConfig.fromEnvironment`.
- OTLP attribute formatting, severity mapping, and payload building.
- Distributed-tracing correlation via `trace_id` / `span_id` / `trace_flags`.
- Automatic `exception.*` attributes for logged errors.
- Graceful, non-throwing error handling with an `onError` callback.
