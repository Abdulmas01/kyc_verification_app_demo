extension StringUtils on String {
  /// Capitalizes only the first letter and makes the rest lowercase
  String get capitalizeFirst {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }

  /// Capitalizes the first letter of every word in the string
  String get capitalizeEachWord {
    if (isEmpty) return this;
    return split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  /// Converts the string to sentence case (first letter uppercase, rest untouched)
  String get sentenceCase {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  /// Removes all commas from the string
  String get removeCommas {
    return replaceAll(',', '');
  }

  /// Removes all characters except digits from the string
  String get digitsOnly {
    return replaceAll(RegExp(r'[^0-9]'), '');
  }

  double get toDouble {
    return double.parse(digitsOnly);
  }

  /// Returns the numeric value clamped to a maximum of 99.
  ///
  /// If the string can be parsed to an integer greater than 99,
  /// this returns `"+99"`.
  String get clampTo99AsMax {
    int? value = int.tryParse(this);
    if (value != null && value > 99) return "+99";
    return (value ?? 0).toString();
  }
}
