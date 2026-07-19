/// The kind of Austrian phone number, derived from the public RTR numbering
/// plan. This describes the number *type*, not the current operator — number
/// portability means a prefix no longer identifies the carrier.
enum PhoneNumberType {
  /// Mobile number (RTR mobile prefix, e.g. 0664, 0699).
  mobile,

  /// Geographic landline (an area code such as 01 Vienna, 0316 Graz).
  landline,

  /// Location-independent / VoIP number (0720).
  voip,

  /// Toll-free number (0800).
  freephone,

  /// Shared-cost number (0810/0820/0821).
  sharedCost,

  /// Premium-rate number (0900/0901/0930/0931/0939).
  premium,

  /// Corporate / private-network number (050x/059x).
  corporate,

  /// Could not be classified (invalid, or a non-AT number).
  unknown,
}
