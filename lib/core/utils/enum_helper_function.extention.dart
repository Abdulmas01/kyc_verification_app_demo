/// Enum for describing name casing styles.
enum EnumNameFormat {
  snakeCase,
  camelCase,
  pascalCase,
  screamingSnakeCase,
  unknown,
}

/// Extension methods for Enum types to convert between different naming styles.
/// All method like toCapitalizedWords, toCamelCase, etc. are based on the
/// canonicalSnakeCase conversion, which first converts any enum name format
/// to snake_case, and then applies the desired transformation.
extension EnumHelper<T extends Enum> on T {
  /// Detects the naming format of the enum value.
  EnumNameFormat get enumNameFormat {
    final raw = name;

    // camelCase
    if (RegExp(r'^[a-z]+(?:[A-Z][a-z0-9]*)+$').hasMatch(raw)) {
      return EnumNameFormat.camelCase;
    }

    // PascalCase
    if (RegExp(r'^[A-Z](?:[a-z0-9]*)(?:[A-Z][a-z0-9]*)*$').hasMatch(raw)) {
      return EnumNameFormat.pascalCase;
    }

    // snake_case
    if (RegExp(r'^[a-z]+(_[a-z0-9]+)*$').hasMatch(raw)) {
      return EnumNameFormat.snakeCase;
    }

    // SCREAMING_SNAKE_CASE
    if (RegExp(r'^[A-Z0-9]+(_[A-Z0-9]+)*$').hasMatch(raw)) {
      return EnumNameFormat.screamingSnakeCase;
    }

    return EnumNameFormat.unknown;
  }

  /// Converts to Capitalized Words
  String get toCapitalizedWords {
    return canonicalSnakeCase
        .split('_')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
  }

  /// Converts to lowercase words
  String get toLowercaseWords => canonicalSnakeCase.replaceAll('_', ' ');

  /// Converts to uppercase words
  String get toUppercaseWords =>
      canonicalSnakeCase.toUpperCase().replaceAll('_', ' ');

  /// Converts to SCREAMING_SNAKE_CASE
  String get toScreamingSnakeCase => canonicalSnakeCase.toUpperCase();

  /// Converts to camelCase
  String get toCamelCase {
    final parts = canonicalSnakeCase.split('_');
    return parts.first +
        parts
            .skip(1)
            .map(
              (p) =>
                  p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '',
            )
            .join();
  }

  /// Converts to PascalCase
  String get toCapitalizedCamelCase {
    return canonicalSnakeCase
        .split('_')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join();
  }

  /// Converts to label-like sentence
  String get toLabel {
    final parts = canonicalSnakeCase.split('_');
    if (parts.isEmpty) return '';
    return parts
        .asMap()
        .entries
        .map((entry) {
          final i = entry.key;
          final w = entry.value;
          return i == 0 ? '${w[0].toUpperCase()}${w.substring(1)}' : w;
        })
        .join(' ');
  }

  /// Converts any naming style to canonical snake_case.
  ///
  /// Handles camelCase, PascalCase, SCREAMING_SNAKE_CASE and acronyms.
  String get canonicalSnakeCase {
    final raw = name;

    if (enumNameFormat == EnumNameFormat.snakeCase) {
      return raw;
    }

    if (enumNameFormat == EnumNameFormat.screamingSnakeCase) {
      return raw.toLowerCase();
    }

    // Insert underscores between acronym boundaries (HTTPServer → HTTP_Server)
    var snake = raw.replaceAllMapped(
      RegExp(r'([A-Z]+)([A-Z][a-z])'),
      (m) => '${m[1]}_${m[2]}',
    );

    // Insert underscores between camel-case boundaries (serverName → server_Name)
    snake = snake.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]}_${m[2]}',
    );

    return snake.toLowerCase().replaceAll(RegExp(r'_+'), '_');
  }
}

/// Normalize any enum-like string into canonical snake_case.
String normalizeEnumValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  // If already snake/screaming snake, normalize to lowercase snake.
  if (RegExp(r'^[A-Z0-9]+(_[A-Z0-9]+)*$').hasMatch(trimmed)) {
    return trimmed.toLowerCase();
  }
  if (RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$').hasMatch(trimmed)) {
    return trimmed;
  }

  // Convert camelCase/PascalCase to snake_case.
  var snake = trimmed.replaceAllMapped(
    RegExp(r'([A-Z]+)([A-Z][a-z])'),
    (m) => '${m[1]}_${m[2]}',
  );
  snake = snake.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (m) => '${m[1]}_${m[2]}',
  );
  return snake.toLowerCase().replaceAll(RegExp(r'_+'), '_');
}
