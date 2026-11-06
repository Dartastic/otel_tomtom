// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_tomtom_suppression.dart';

const _tracerName = 'dartastic_otel_libs_tomtom';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class TomtomResult {
  /// Creates a result.
  const TomtomResult({
    this.itemCount,
    this.creditsCharged,
    this.travelMode,
    this.trafficUsed,
    this.tier,
    this.requestId,
    this.statusCode,
  });

  /// Result rows / route alternatives / search hits.
  final int? itemCount;

  /// TomTom credits debited by this call (TomTom's primary billing
  /// unit; products charge different credit weights). Reported via
  /// `x-tt-credits-used` style headers or response metadata.
  final int? creditsCharged;

  /// `car` / `truck` / `pedestrian` / `bicycle` / `motorcycle` /
  /// `taxi` / `bus` — affects routing pricing.
  final String? travelMode;

  /// Whether live traffic was consulted (separately billed signal).
  final bool? trafficUsed;

  /// `essential` / `business` / `enterprise`.
  final String? tier;

  /// `Tracking-ID` / `x-tt-tracking-id`.
  final String? requestId;
  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class TomtomCallResult<T> {
  /// Creates a call result.
  const TomtomCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final TomtomResult? result;
}

/// Wraps a TomTom Maps API call in a CLIENT span. [product] is one of
/// `search`, `routing`, `matrix_routing`, `traffic`, `map_display`,
/// `ev_charging`, `geofencing`, `notifications`, `snap_to_roads`.
Future<T> tracedTomtom<T>({
  required String product,
  required Future<TomtomCallResult<T>> Function() invoke,
  String? operation,
  String? apiVersion,
}) async {
  if (tomtomInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final spanName =
      operation == null ? 'tomtom $product' : 'tomtom $product.$operation';
  final m = <String, Object>{
    'rpc.system': 'tomtom',
    'rpc.method': operation ?? product,
    'tomtom.product': product,
  };
  if (operation != null) m['tomtom.operation'] = operation;
  if (apiVersion != null) m['tomtom.api_version'] = apiVersion;

  final span = _tracer().startSpan(
    spanName,
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTelAPI.attributeInt(
          'tomtom.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.creditsCharged != null) {
        extras.add(OTelAPI.attributeInt(
          'tomtom.credits_charged',
          r.result!.creditsCharged!,
        ));
      }
      if (r.result!.travelMode != null) {
        extras.add(OTelAPI.attributeString(
          'tomtom.travel_mode',
          r.result!.travelMode!,
        ));
      }
      if (r.result!.trafficUsed != null) {
        extras.add(OTelAPI.attributeBool(
          'tomtom.traffic_used',
          r.result!.trafficUsed!,
        ));
      }
      if (r.result!.tier != null) {
        extras.add(OTelAPI.attributeString(
          'tomtom.tier',
          r.result!.tier!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'tomtom.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'TomTom HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
