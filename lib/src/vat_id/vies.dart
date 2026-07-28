/// A request the caller can send to the EU's VIES service.
///
/// The package builds it and parses the answer, but never performs the call:
/// staying offline is a property of this library, and the caller is the one
/// who knows about timeouts, retries and rate limits.
class ViesRequest {
  /// Creates a request descriptor.
  const ViesRequest({
    required this.url,
    required this.method,
    required this.headers,
  });

  /// Fully qualified endpoint URL.
  final String url;

  /// HTTP method — always `GET` for this endpoint.
  final String method;

  /// Headers the service expects.
  final Map<String, String> headers;
}

/// What VIES said about a VAT ID.
///
/// Only returned when the service gave a conclusive answer. An unreachable
/// member state is not a rejection, so `VatId.parseViesResponse` returns null
/// rather than a [VatRegistration] with `valid: false` in that case.
class VatRegistration {
  /// Creates a registration answer.
  const VatRegistration({
    required this.valid,
    required this.name,
    required this.address,
    required this.requestDate,
  });

  /// Whether the number is currently registered for intra-EU trade.
  final bool valid;

  /// The registered name, or null when the member state does not disclose it.
  ///
  /// Several states answer with `---` instead of a name; that is "withheld",
  /// not "empty", and both collapse to null here.
  final String? name;

  /// The registered address, or null when it is not disclosed.
  final String? address;

  /// The service's timestamp for the answer, as returned.
  final String? requestDate;
}
