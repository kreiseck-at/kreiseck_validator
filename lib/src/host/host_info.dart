/// The kind of host a [HostInfo] describes.
enum HostType { hostname, ipv4, ipv6 }

/// Structured data parsed out of a host by `Host.parse`.
class HostInfo {
  /// Creates a [HostInfo].
  const HostInfo({
    required this.host,
    required this.type,
    required this.port,
    required this.hasPort,
  });

  /// The host without brackets or a port, lower-cased.
  final String host;

  /// Whether [host] is a hostname, an IPv4 address or an IPv6 address.
  final HostType type;

  /// The port number, when present.
  final int? port;

  /// Whether a port was present in the input.
  final bool hasPort;
}
