/// The MAC address family: EUI-48 (12 hex digits) or EUI-64 (16 hex digits).
enum MacAddressType { eui48, eui64 }

/// Structured data parsed out of a MAC address by `MacAddress.parse`.
class MacInfo {
  /// Creates a [MacInfo].
  const MacInfo({
    required this.oui,
    required this.nic,
    required this.isUnicast,
    required this.isMulticast,
    required this.isUniversal,
    required this.isLocal,
    required this.type,
  });

  /// Organizationally Unique Identifier: the first 3 octets, in normalized
  /// (lower-case colon) notation.
  final String oui;

  /// Network Interface Controller identifier: the remaining octets, in
  /// normalized (lower-case colon) notation.
  final String nic;

  /// True when the address identifies a single station (I/G bit unset).
  final bool isUnicast;

  /// True when the address is a group/multicast address (I/G bit set).
  final bool isMulticast;

  /// True when the OUI is IEEE-assigned (U/L bit unset).
  final bool isUniversal;

  /// True when the address is locally administered (U/L bit set).
  final bool isLocal;

  /// Whether this is an EUI-48 (12 hex digits) or EUI-64 (16 hex digits)
  /// address.
  final MacAddressType type;
}
