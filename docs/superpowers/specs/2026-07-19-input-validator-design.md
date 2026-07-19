# input_validator — Design (V1)

Status: approved
Date: 2026-07-19
License: Apache-2.0

## Zweck

Ein Dart-Paket zum **Validieren**, **Normalisieren** und **Formatieren („verschönern")**
gängiger Nutzereingaben. Zero-Dependency, handgeschrieben, sehr gut dokumentiert.

Ausdrückliche Ziele:

- **Keine externen Abhängigkeiten.** Alle Algorithmen selbst implementiert.
- **Sehr gute Doku.** Jede öffentliche API mit dartdoc; `doc/` erklärt die Algorithmen.
- **Sprachübergreifend konsistent.** V1 ist Dart-only; ein späterer npm-Port soll
  identisches Verhalten haben. Dafür liegen die Testfälle als sprachunabhängige
  JSON-Vektoren vor.

Nicht-Ziele (V1):

- Kein Netzwerk (keine DNS-/MX-Abfragen, keine Online-Prüfungen).
- Keine vollständige internationale Abdeckung — länderspezifische Teile nur DACH.
- Kein npm-Paket in V1 (nur Vorbereitung durch Test-Vektoren).

## Umfang V1

Fünf Eingabetypen:

| Typ         | Validierung                             | Normalisierung           | Formatierung („verschönern")          |
|-------------|-----------------------------------------|--------------------------|----------------------------------------|
| Email       | pragmatische Syntax + Tippfehler-Heuristik | trim, lowercase        | (Anzeige = normalisiert)               |
| Telefon     | E.164 + DACH-Nummernpläne (DE/AT/CH)     | → E.164                  | national & international lesbar         |
| URL/Domain  | Schema/Host/TLD-Plausibilität            | Protokoll, trailing slash| gekürzte Anzeigeform                    |
| IBAN        | Mod-97 + DACH-Längen (DE/AT/CH)          | Großbuchstaben, ohne Space | 4er-Blöcke                           |
| Kreditkarte | Luhn + Längen je Netzwerk                 | nur Ziffern              | Netzwerk-typische Blöcke               |

Länderspezifisches (Telefon-Formate, IBAN-Längen): **DE, AT, CH**.
Prüfsummen (Luhn, Mod-97) sind generisch und funktionieren länderunabhängig.

## Öffentliche API

Jeder Typ ist eine Klasse mit statischen Methoden — konsistentes Muster über alle Typen.
Vier Grundoperationen (nicht jeder Typ braucht alle):

- `isValid(String input) -> bool` — schnelle Ja/Nein-Prüfung.
- `validate(String input) -> ValidationResult` — Detailergebnis mit Fehlercodes.
- `normalize(String input) -> String` — kanonische Form (wirft `FormatException` bei ungültig).
- `format(String input, {...}) -> String` — verschönerte Anzeigeform (wirft `FormatException`);
  zusätzlich `tryFormat(...) -> String?`.

Beispiele:

```dart
Email.isValid('a@b.com');                     // true
Email.normalize(' A@B.com ');                 // 'a@b.com'
Email.validate('a@gmial.com');                // Valid, mit Vorschlag 'a@gmail.com'

Phone.isValid('+43 660 1234567');             // true
Phone.format('06601234567', country: Country.at); // '+43 660 1234567'

Iban.format('AT611904300234573201');          // 'AT61 1904 3002 3457 3201'
CreditCard.format('4111111111111111');        // '4111 1111 1111 1111'

Url.normalize('Example.com/path/');           // 'https://example.com/path'
```

### Ergebnismodell

`validate()` gibt ein `ValidationResult` zurück (kein Throw) — idiomatisch und bequem:

```dart
sealed class ValidationResult {}

class Valid extends ValidationResult {
  final String normalized;           // kanonische Form
  final List<Suggestion> suggestions; // z.B. Tippfehler-Domain-Vorschlag; meist leer
}

class Invalid extends ValidationResult {
  final List<ValidationIssue> issues; // mind. 1 Eintrag
}

class ValidationIssue {
  final IssueCode code;    // Enum, testbar & übersetzbar
  final String message;    // menschenlesbarer Default-Text (Englisch)
}
```

- `isValid(x)` ist definiert als `validate(x) is Valid`.
- Fehler-**Codes** sind Enums (z.B. `emailMissingAt`, `ibanBadChecksum`, `phoneTooShort`).
  Messages sind nur der englische Default; Codes ermöglichen eigene Übersetzungen.
- `Suggestion` trägt Typ + korrigierten Wert (für die Email-Tippfehler-Heuristik).

## Verhalten je Typ

### Email
Pragmatische Prüfung: genau ein `@`, nicht-leerer local-part, Domain mit mindestens
einem Punkt und plausibler TLD; gängige Regeln, **keine** exotischen RFC-5322-Fälle
(quoted strings, Kommentare). Normalisierung: trim + lowercase.
**Tippfehler-Heuristik (offline):** kleine Distanz zu bekannten Domains
(`gmial.com` → `gmail.com`) erzeugt eine `Suggestion` — ändert das Ergebnis nicht auf
Invalid, sondern schlägt nur vor. Rein lokal, keine Netzwerkabfrage.

### Telefon
Akzeptiert E.164 (`+…`) sowie nationale DACH-Schreibweisen mit gängigen Trennern
(Leerzeichen, `-`, `/`, `()`). Normalisierung → E.164. Formatierung: lesbare nationale
und internationale Form je Land (DE/AT/CH). Ohne Ländercode und ohne `+` ist `country`
erforderlich; fehlt er → `Invalid(phoneAmbiguousCountry)`.

### URL/Domain
Plausibilitätsprüfung von Schema (http/https), Host und TLD; keine vollständige
URL-Grammatik. Normalisierung: Protokoll ergänzen (Default `https`), Host lowercase,
überflüssigen trailing slash entfernen. Formatierung: gekürzte Anzeigeform
(z.B. ohne Protokoll/`www`) für UI.

### IBAN
Validierung per Mod-97-Prüfsumme plus Längen-/Formatcheck für DE/AT/CH; andere Länder
werden nur per Prüfsumme akzeptiert (ohne Längengarantie, entsprechend gekennzeichnet).
Normalisierung: Großbuchstaben, ohne Leerzeichen. Formatierung: 4er-Blöcke.

### Kreditkarte
Luhn-Prüfung plus Längenprüfung je Netzwerk (Visa, Mastercard, Amex …), Netzwerk-
Erkennung über IIN-Präfixe. Normalisierung: nur Ziffern. Formatierung: netzwerktypische
Blockung (Amex 4-6-5, sonst 4-4-4-4).

## Projektstruktur

```
input_validator/
  lib/
    input_validator.dart          # Barrel-Export der öffentlichen API
    src/
      common/                     # ValidationResult, ValidationIssue, IssueCode,
                                  #   Suggestion, Country, gemeinsame Helfer
      email/
      phone/
      url/
      iban/
      credit_card/
  test/
    email_test.dart
    phone_test.dart
    url_test.dart
    iban_test.dart
    credit_card_test.dart
    vectors_test.dart             # lädt & prüft die JSON-Vektoren
    vectors/                      # sprachunabhängige Testfälle (JSON)
      email.json  phone.json  url.json  iban.json  credit_card.json
  doc/                            # Erklärung der Algorithmen (Luhn, Mod-97, E.164, …)
  README.md
  CHANGELOG.md
  LICENSE                         # Apache-2.0
  pubspec.yaml
  analysis_options.yaml           # strenges Lint-Level
```

Jeder `src/<typ>/`-Ordner bündelt Logik + interne Doku eines Typs und ist unabhängig
testbar. `common/` definiert die geteilten Verträge, sonst hängen die Typen nicht
voneinander ab.

## Konsistenz für spätere Ports

Die maßgeblichen Testfälle liegen als **JSON-Vektoren** in `test/vectors/`:
Eingabe → erwartete Operation-Ergebnisse (isValid/normalize/format/Fehlercode).
Der Dart-Test (`vectors_test.dart`) lädt und prüft sie. Ein späterer npm-Port lädt
**dieselben Dateien** — so kann keine Implementierung stillschweigend abweichen.
Sprachspezifische Unit-Tests ergänzen die Vektoren um Rand-/Fehlerfälle.

## Doku & Qualität

- **dartdoc** auf jeder öffentlichen API.
- **`doc/`** erklärt die eingesetzten Algorithmen (Luhn, Mod-97, E.164, Tippfehler-Distanz).
- **README** mit Copy-Paste-Beispielen pro Typ + Feature-/Länder-Matrix.
- **Lint:** strenges Analyse-Level; Ziel hohe Test-Coverage.
- **Lizenz:** Apache-2.0 (breite Adoption inkl. LLM-/Tool-Nutzung, Credit + Patentschutz).

## Offene Punkte für später (nicht V1)

- npm-Port auf Basis der JSON-Vektoren.
- Erweiterung der Länderabdeckung über DACH hinaus.
- Weitere Typen (z.B. Postleitzahl, Steuernummer, UUID).
