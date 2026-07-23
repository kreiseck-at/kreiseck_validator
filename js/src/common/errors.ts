/// Thrown by normalize/format on invalid input (mirrors Dart's FormatException).
export class FormatError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'FormatError';
  }
}
