# OpenTelemetry Logging for Dart

[![pub package](https://img.shields.io/pub/v/otel_logging_dart.svg)](https://pub.dev/packages/otel_logging_dart)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`otel_logging_dart` ships your Dart and Flutter application logs to an
[OpenTelemetry](https://opentelemetry.io/) collector using the **OTLP/HTTP
(JSON)** protocol. It integrates with the standard
[`package:logging`](https://pub.dev/packages/logging) facade and formats
severities, attributes, and distributed-tracing context according to the
[OpenTelemetry logs data model](https://opentelemetry.io/docs/specs/otel/logs/data-model/).

It is written in **pure Dart** (no `dart:io`), so the same code runs on
server-side Dart, Flutter mobile and desktop, and the web.

---

## Table of contents

- [Why this package](#why-this-package)
- [Features](#features)
- [Requirements & compatibility](#requirements--compatibility)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Usage guide](#usage-guide)
  - [Integrating with `package:logging`](#integrating-with-packagelogging)
  - [Structured attributes](#structured-attributes)
  - [Global attributes](#global-attributes)
  - [Distributed tracing](#distributed-tracing)
  - [Logging exceptions](#logging-exceptions)
  - [Authentication & custom headers](#authentication--custom-headers)
  - [Emitting records directly](#emitting-records-directly)
  - [Handling export failures](#handling-export-failures)
  - [Enabling / disabling at runtime](#enabling--disabling-at-runtime)
  - [Cleanup](#cleanup)
- [Configuration reference](#configuration-reference)
  - [Configuring from environment variables](#configuring-from-environment-variables)
- [How values are mapped](#how-values-are-mapped)
  - [Severity mapping](#severity-mapping)
  - [Attribute type mapping](#attribute-type-mapping)
  - [The OTLP payload](#the-otlp-payload)
- [Flutter notes](#flutter-notes)
- [Running a local collector](#running-a-local-collector)
- [Architecture](#architecture)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Why this package

OpenTelemetry is the vendor-neutral standard for telemetry (logs, metrics, and
traces). Most backends — Grafana Loki, Honeycomb, Datadog, New Relic, Elastic,
SigNoz, Jaeger-adjacent stacks, or a self-hosted
[OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) — can ingest
**OTLP** directly. This package lets a Dart/Flutter app become a first-class log
source in that pipeline without pulling in a heavy SDK: you keep using
`package:logging` as normal, and each record is converted to a correctly-shaped
OTLP log record and `POST`ed to your collector's `/v1/logs` endpoint.

## Features

- 🔄 **Ships logs to any OTLP/HTTP collector** (`/v1/logs`, JSON encoding).
- 🪵 **Drop-in `package:logging` integration** — one call wires it to a logger.
- 🧩 **Correct OTLP typing** — strings, ints, doubles, bools, and JSON-encoded
  maps/lists become the proper `AnyValue` shapes.
- 🔍 **Trace correlation** — `trace_id` / `span_id` / `trace_flags` are validated
  and attached so logs line up with your traces.
- 🧨 **Exception expansion** — errors become semantic `exception.type`,
  `exception.message`, and `exception.stacktrace` attributes.
- 🏷️ **Resource & global attributes** — `service.name`, `service.version`,
  `deployment.environment`, `host.name`, plus any attributes you add to every
  record.
- 🛡️ **Safe by design** — logging never throws; transport failures are routed to
  an `onError` callback, with a re-entrancy guard so a failing logger can't loop.
- 🌐 **Pure Dart** — no `dart:io`; runs on server, mobile, desktop, and web.
- 🔌 **Injectable everything** — bring your own `http.Client`, `SeverityMapper`,
  `AttributeFormatter`, or `LogPayloadBuilder` for testing or customization.

## Requirements & compatibility

| | |
|---|---|
| Dart SDK | `>=3.5.0 <4.0.0` |
| Runtime deps | [`http`](https://pub.dev/packages/http) `^1.2.0`, [`logging`](https://pub.dev/packages/logging) `^1.2.0` |
| Platforms | Dart VM/server, Flutter Android/iOS/macOS/Windows/Linux, Web |
| Protocol | OTLP/HTTP with JSON encoding (the collector's `/v1/logs` route) |

> This package targets **OTLP/HTTP + JSON**, not gRPC and not protobuf-over-HTTP.
> Point it at the HTTP receiver of your collector (default port `4318`).

## Installation

```bash
dart pub add otel_logging_dart
```

…or add it manually to `pubspec.yaml`:

```yaml
dependencies:
  otel_logging_dart: ^0.1.0
```

Then import it:

```dart
import 'package:otel_logging_dart/otel_logging_dart.dart';
```

## Quick start

```dart
import 'package:logging/logging.dart';
import 'package:otel_logging_dart/otel_logging_dart.dart';

void main() {
  final exporter = OtelLogExporter(
    config: const OtelConfig(
      enabled: true,
      endpoint: 'http://localhost:4318/v1/logs',
      serviceName: 'my-dart-app',
      serviceVersion: '1.4.2',
      environment: 'production',
    ),
    onError: (error, stackTrace) => print('OTLP export failed: $error'),
  );

  Logger.root.level = Level.ALL;          // decide which records flow
  exporter.attachToLogger(Logger.root);   // forward them to the collector

  Logger('orders').info('order processed');
}
```

That's it — every record that passes the logger's level is converted to an OTLP
log record and sent to your collector.

## Usage guide

### Integrating with `package:logging`

`attachToLogger` subscribes to a logger's `onRecord` stream and exports each
record. It returns the `StreamSubscription`, so you can cancel it later.

```dart
final subscription = exporter.attachToLogger(Logger.root);
// ...
await subscription.cancel(); // stop forwarding to the collector
```

Remember to set a level — `package:logging` drops everything by default:

```dart
Logger.root.level = Level.ALL; // or Level.INFO, Level.WARNING, etc.
```

You can attach to the root logger (captures everything) or to a specific named
logger to scope what gets exported.

### Structured attributes

`package:logging` carries a structured payload through the message **object**.
Pass a `Map` and every entry becomes an OTLP attribute. The `message` key (if
present) becomes the log **body**:

```dart
Logger('orders').info({
  'message': 'order processed',
  'order_id': 1234,
  'amount': 49.99,
  'paid': true,
  'items': ['sku-1', 'sku-2'],   // lists/maps are JSON-encoded into a string
});
```

If you log a plain `String`, it becomes the body and the record simply has no
custom attributes (the logger name is always added as `logger.name`).

### Global attributes

Attributes that should appear on **every** record — team, region, build id, etc.
— go on the config. They are emitted ahead of per-record attributes:

```dart
const OtelConfig(
  enabled: true,
  endpoint: 'http://localhost:4318/v1/logs',
  serviceName: 'my-dart-app',
  globalAttributes: {
    'team': 'payments',
    'region': 'eu-west-1',
  },
);
```

### Distributed tracing

To correlate a log with a trace, include the reserved keys in your attribute
map. They are lifted out of the attributes and placed on the dedicated OTLP
fields:

```dart
Logger('orders').info({
  'message': 'processing order',
  'trace_id': '0af7651916cd43dd8448eb211c80319c', // 32 lowercase hex chars
  'span_id':  'b7ad6b7169203331',                 // 16 lowercase hex chars
  'trace_flags': 1,                               // optional, 0–255
});
```

Validation rules (invalid context is dropped silently rather than corrupting the
record):

- **`trace_id`** must be exactly 32 hexadecimal characters and not all zeros.
- **`span_id`** must be exactly 16 hexadecimal characters and not all zeros.
- Values are trimmed and lower-cased before validation.
- **`trace_flags`**: if a valid `trace_id` and `span_id` are present and you omit
  `trace_flags` (or pass something out of the `0–255` range), the record is
  marked **sampled** (`flags = 1`). If either id is missing/invalid, `flags = 0`.

### Logging exceptions

Errors passed through `package:logging` (the optional second/third arguments)
are expanded into semantic attributes:

```dart
try {
  // ...
} catch (error, stackTrace) {
  Logger('payments').severe('payment failed', error, stackTrace);
}
```

produces the attributes:

- `exception.type` — the error's runtime type
- `exception.message` — `error.toString()`
- `exception.stacktrace` — the stack trace (when provided)

You can also attach an error to a record you build yourself via
`OtelLogRecord(error: ..., stackTrace: ...)`, or include an `exception` /
`error` key in an attribute map.

### Authentication & custom headers

Most hosted collectors require an API key or bearer token. Add any HTTP headers
via `headers`; they are sent with every request alongside `Content-Type`:

```dart
const OtelConfig(
  enabled: true,
  endpoint: 'https://otlp.example-vendor.com/v1/logs',
  serviceName: 'my-dart-app',
  headers: {
    'Authorization': 'Bearer <token>',
    'x-api-key': '<key>',
  },
);
```

### Emitting records directly

You don't have to use `package:logging` at all. Build and emit an
`OtelLogRecord` yourself:

```dart
await exporter.emit(
  OtelLogRecord(
    severityNumber: SeverityMapper.severityWarn,
    severityText: 'warn',
    body: 'cache miss',
    attributes: {'key': 'user:42'},
    // optional: time, traceId, spanId, traceFlags, error, stackTrace
  ),
);
```

`emit` returns a `Future` that completes once the record has been sent (or its
failure handled). It never throws.

### Handling export failures

The logging path is intentionally non-throwing. Network errors, timeouts,
non-2xx responses, and a missing endpoint are all routed to your `onError`
callback instead of bubbling up into your app:

```dart
OtelLogExporter(
  config: config,
  onError: (error, stackTrace) {
    // e.g. forward to a local file logger, increment a metric, etc.
    stderr.writeln('Failed to export log: $error');
  },
);
```

A re-entrancy guard ensures that if your `onError` handler itself logs (and that
log is also exported and also fails), it won't spiral into an infinite loop.

### Enabling / disabling at runtime

When `enabled` is `false`, `emit` is a no-op and nothing is sent — handy for
disabling export in tests or local development without removing the wiring:

```dart
final config = OtelConfig.fromEnvironment(Platform.environment)
    .copyWith(enabled: !kReleaseMode ? false : true);
```

### Cleanup

If you let the exporter create its own `http.Client`, call `close()` when you're
done so the client's resources are released (and further `emit` calls become
no-ops). If you passed in your own client, you own its lifecycle.

```dart
exporter.close();
```

## Configuration reference

`OtelConfig` is an immutable value object. Construct it directly or use
`copyWith` to derive variants.

| Field | Type | Default | Description |
|---|---|---|---|
| `enabled` | `bool` | `false` | Master switch. When `false`, `emit` does nothing. |
| `endpoint` | `String` | `''` | OTLP/HTTP logs endpoint, e.g. `http://localhost:4318/v1/logs`. |
| `serviceName` | `String` | `'dart-app'` | `service.name` resource attribute. |
| `serviceVersion` | `String` | `'1.0.0'` | `service.version` resource attribute. |
| `environment` | `String` | `'production'` | `deployment.environment` resource attribute. |
| `hostName` | `String` | `'unknown'` | `host.name` resource attribute. |
| `timeout` | `Duration` | `5s` | Per-request HTTP timeout. |
| `headers` | `Map<String, String>` | `{}` | Extra headers (auth, etc.) on every request. |
| `globalAttributes` | `Map<String, Object?>` | `{}` | Attributes added to every log record. |
| `scopeName` | `String` | `'dart-logs'` | Instrumentation scope name in `scopeLogs`. |
| `scopeVersion` | `String` | `'unknown'` | Instrumentation scope version in `scopeLogs`. |

### Configuring from environment variables

`OtelConfig.fromEnvironment` reads a string map (typically
`Platform.environment` on the Dart VM):

```dart
import 'dart:io';

final config = OtelConfig.fromEnvironment(
  Platform.environment,
  hostName: Platform.localHostname, // optional; defaults to 'unknown'
);
```

> `dart:io` is used **by you** here, not by the package — so the core library
> stays web-compatible. On web, build `OtelConfig` directly instead.

| Environment variable | Maps to | Default |
|---|---|---|
| `OTEL_ENABLED` | `enabled` (`true`/`1`/`yes`/`on` → true) | `false` |
| `OTEL_EXPORTER_ENDPOINT` | `endpoint` | `''` |
| `OTEL_SERVICE_NAME` | `serviceName` | `dart-app` |
| `OTEL_SERVICE_VERSION` | `serviceVersion` | `1.0.0` |
| `OTEL_ENVIRONMENT` (falls back to `APP_ENV`) | `environment` | `production` |
| `OTEL_HTTP_TIMEOUT` | `timeout` (seconds) | `5` |

`headers`, `globalAttributes`, and `hostName` can also be passed as named
arguments to `fromEnvironment`.

## How values are mapped

### Severity mapping

`SeverityMapper` buckets a `package:logging` `Level` into an OTLP
`severityNumber`. The `severityText` is the lower-cased Dart level name, so it
stays meaningful even for custom levels. Mapping is **range-based**, so any
custom integer level value still lands in a sensible bucket.

| `package:logging` level | value | `severityNumber` | `severityText` |
|---|---|---|---|
| `FINEST` | 300 | 1 (TRACE) | `finest` |
| `FINER` | 400 | 1 (TRACE) | `finer` |
| `FINE` | 500 | 5 (DEBUG) | `fine` |
| `CONFIG` | 700 | 5 (DEBUG) | `config` |
| `INFO` | 800 | 9 (INFO) | `info` |
| `WARNING` | 900 | 13 (WARN) | `warning` |
| `SEVERE` | 1000 | 17 (ERROR) | `severe` |
| `SHOUT` | 1200 | 21 (FATAL) | `shout` |

Range boundaries: `[0,500) → 1`, `[500,800) → 5`, `[800,900) → 9`,
`[900,1000) → 13`, `[1000,1200) → 17`, `[1200,∞) → 21`. The numeric constants are
exposed as `SeverityMapper.severityTrace`, `…severityDebug`, `…severityInfo`,
`…severityWarn`, `…severityError`, and `…severityFatal`.

### Attribute type mapping

`AttributeFormatter` converts each Dart value to an OTLP `AnyValue`:

| Dart value | OTLP value |
|---|---|
| `String` | `{ "stringValue": ... }` |
| `int` | `{ "intValue": ... }` |
| `double` | `{ "doubleValue": ... }` |
| `bool` | `{ "boolValue": ... }` |
| `null` | `{ "stringValue": "null" }` |
| `Map` / `Iterable` | JSON-encoded into `{ "stringValue": ... }` |
| anything else | `{ "stringValue": value.toString() }` |

An `exception` or `error` key whose value is an error object is expanded into the
`exception.*` attributes described above instead of being formatted as a single
value.

### The OTLP payload

Each record is sent as a complete `resourceLogs` envelope. For example,
`Logger('orders').info({'message': 'order processed', 'order_id': 1234})` with
the quick-start config produces roughly:

```json
{
  "resourceLogs": [
    {
      "resource": {
        "attributes": [
          { "key": "service.name", "value": { "stringValue": "my-dart-app" } },
          { "key": "service.version", "value": { "stringValue": "1.4.2" } },
          { "key": "deployment.environment", "value": { "stringValue": "production" } },
          { "key": "host.name", "value": { "stringValue": "unknown" } }
        ]
      },
      "scopeLogs": [
        {
          "scope": { "name": "dart-logs", "version": "unknown" },
          "logRecords": [
            {
              "timeUnixNano": "1717977600000000000",
              "severityNumber": 9,
              "severityText": "info",
              "body": { "stringValue": "order processed" },
              "attributes": [
                { "key": "order_id", "value": { "intValue": 1234 } },
                { "key": "logger.name", "value": { "stringValue": "orders" } }
              ],
              "droppedAttributesCount": 0,
              "flags": 0,
              "traceId": "",
              "spanId": ""
            }
          ]
        }
      ]
    }
  ]
}
```

Timestamps are emitted as nanoseconds since the Unix epoch
(`microsecondsSinceEpoch * 1000`) encoded as a string, per the OTLP/JSON
encoding of 64-bit fields.

## Flutter notes

- Works on all Flutter targets. On web, configure `OtelConfig` directly (no
  `Platform.environment`).
- Send your collector endpoint over **HTTPS** in production; on Android, cleartext
  HTTP to a dev collector may require a network-security-config exception.
- For mobile apps, point at a collector you control (or a vendor's OTLP ingest)
  rather than a collector on `localhost`.
- Consider only enabling export in release builds, or gating it behind a user
  consent / telemetry setting.

## Running a local collector

A minimal collector to receive logs over OTLP/HTTP on port `4318`:

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318

exporters:
  debug:
    verbosity: detailed

service:
  pipelines:
    logs:
      receivers: [otlp]
      exporters: [debug]
```

```bash
docker run --rm -p 4318:4318 \
  -v "$(pwd)/otel-collector-config.yaml:/etc/otelcol/config.yaml" \
  otel/opentelemetry-collector:latest
```

Then set `endpoint: 'http://localhost:4318/v1/logs'` and watch the records print
in the collector's debug output.

## Architecture

The package is small and composable; each class has a single responsibility and
can be replaced via constructor injection.

| Class | Responsibility |
|---|---|
| `OtelLogExporter` | Builds payloads, `POST`s them, and bridges `package:logging`. |
| `OtelConfig` | Immutable configuration (with `fromEnvironment` and `copyWith`). |
| `OtelLogRecord` | Framework-agnostic log entry model (plus `fromLogging`). |
| `LogPayloadBuilder` | Constructs the OTLP `resourceLogs` envelope. |
| `AttributeFormatter` | Converts Dart values to OTLP typed attributes. |
| `SeverityMapper` | Maps `package:logging` levels to OTLP severities. |

```
Logger.info({...})
      │  package:logging LogRecord
      ▼
OtelLogExporter.attachToLogger ──▶ OtelLogRecord.fromLogging
      │                                   │  (SeverityMapper)
      ▼                                   ▼
OtelLogExporter.emit ──▶ LogPayloadBuilder.build ──▶ AttributeFormatter
      │                                   │
      ▼                                   ▼
http.Client.post(endpoint)  ◀── OTLP resourceLogs JSON
```

## Testing

The package ships with a full unit-test suite. To run it:

```bash
dart test
```

Because every collaborator is injectable, testing your own integration is easy —
pass a [`MockClient`](https://pub.dev/documentation/http/latest/testing/MockClient-class.html)
from `package:http`:

```dart
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

final client = MockClient((request) async {
  // assert on request.body here
  return http.Response('', 204);
});

final exporter = OtelLogExporter(config: config, client: client);
```

## Troubleshooting

**Nothing is being sent.**
Check that `enabled` is `true`, the logger's `level` is low enough to emit the
records, and `endpoint` is non-empty. An empty endpoint is reported through
`onError` as a `StateError`.

**I get a `ClientException` in `onError`.**
The collector returned a non-2xx status, or the host was unreachable. The
exception message includes the HTTP status (e.g. `HTTP 500`). Verify the
endpoint path ends in `/v1/logs` and that any required auth headers are set.

**Requests time out.**
Increase `timeout`, or check connectivity to the collector. In high-volume apps,
prefer a nearby/batching collector.

**My attributes show up as a JSON string.**
Maps and lists are JSON-encoded into a single `stringValue` (OTLP attributes are
flat). Flatten them into individual keys if you need them queryable.

## Contributing

Issues and pull requests are welcome. Please run `dart analyze`, `dart format .`,
and `dart test` before submitting.

## License

MIT — see [LICENSE](LICENSE).
