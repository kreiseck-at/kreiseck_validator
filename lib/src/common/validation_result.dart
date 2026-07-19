import 'issue_code.dart';

/// Outcome of a `validate` call: either [Valid] or [Invalid].
sealed class ValidationResult {
  const ValidationResult();
}

/// A successful validation carrying the canonical [normalized] form.
class Valid extends ValidationResult {
  /// Creates a valid result.
  const Valid(this.normalized, {this.suggestions = const []});

  /// The canonical form of the accepted input.
  final String normalized;

  /// Optional, non-blocking hints (e.g. a likely typo correction).
  final List<Suggestion> suggestions;
}

/// A failed validation carrying one or more [issues].
class Invalid extends ValidationResult {
  /// Creates an invalid result; [issues] must be non-empty.
  const Invalid(this.issues);

  /// The reasons the input was rejected.
  final List<ValidationIssue> issues;
}

/// A single validation failure reason.
class ValidationIssue {
  /// Creates an issue from a stable [code] and a human-readable [message].
  const ValidationIssue(this.code, this.message);

  /// Stable, translatable identifier.
  final IssueCode code;

  /// English default message; translate via [code].
  final String message;
}

/// A non-blocking correction hint attached to a [Valid] result.
class Suggestion {
  /// Creates a suggestion for a corrected [value] with a machine [reason].
  const Suggestion(this.value, this.reason);

  /// The suggested corrected input.
  final String value;

  /// Machine-readable reason, e.g. `'typo-domain'`.
  final String reason;
}
