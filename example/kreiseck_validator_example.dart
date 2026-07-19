// Runnable tour of kreiseck_validator.
//
//   dart run example/kreiseck_validator_example.dart
//
// Every type exposes the same operations: isValid / validate / normalize /
// format (+ tryFormat). validate() returns a sealed ValidationResult you can
// switch over exhaustively.

import 'package:kreiseck_validator/kreiseck_validator.dart';

void main() {
  _email();
  _phone();
  _url();
  _iban();
  _creditCard();
}

void _email() {
  print('--- Email ---');
  print(Email.isValid('a@b.com')); // true
  print(Email.normalize('  A@B.com ')); // a@b.com

  // A syntactically valid address with a likely typo: the result is still
  // Valid, but carries an offline suggestion (no DNS lookup).
  switch (Email.validate('user@gmial.com')) {
    case Valid(:final normalized, :final suggestions):
      print('valid: $normalized');
      if (suggestions.isNotEmpty) {
        print('did you mean: ${suggestions.first.value}'); // user@gmail.com
      }
    case Invalid(:final issues):
      print('invalid: ${issues.first.code}');
  }
}

void _phone() {
  print('\n--- Phone ---');
  // National input needs a country; E.164 input does not.
  print(Phone.normalize('0660 1234567', country: Country.at)); // +436601234567
  print(Phone.normalize('+43 (0) 660 1234567')); // +436601234567
  print(Phone.format('+436601234567')); // +43 660 1234567
  print(Phone.format('+436601234567', international: false)); // 0660 1234567

  // Without a country a national number is ambiguous.
  switch (Phone.validate('0660 1234567')) {
    case Valid(:final normalized):
      print(normalized);
    case Invalid(:final issues):
      print('rejected: ${issues.first.code}'); // phoneAmbiguousCountry
  }
}

void _url() {
  print('\n--- Url ---');
  print(Url.isValid('example.com:8080')); // true
  print(Url.normalize('Example.com/path/')); // https://example.com/path
  print(Url.format('https://www.example.com/')); // example.com
}

void _iban() {
  print('\n--- Iban ---');
  print(Iban.isValid('AT61 1904 3002 3457 3201')); // true
  print(Iban.format('AT611904300234573201')); // AT61 1904 3002 3457 3201

  // tryFormat returns null instead of throwing on invalid input.
  print(Iban.tryFormat('AT00 not an iban')); // null
}

void _creditCard() {
  print('\n--- CreditCard ---');
  print(CreditCard.network('4111111111111111')); // CardNetwork.visa
  print(CreditCard.format('4111111111111111')); // 4111 1111 1111 1111
  print(CreditCard.format('378282246310005')); // 3782 822463 10005 (Amex 4-6-5)
  print(CreditCard.isValid('4111 1111 1111 1112')); // false (fails Luhn)
}
