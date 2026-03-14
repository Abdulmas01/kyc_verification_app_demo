/// Utilities for merging edited values with existing values.
///
/// This extension is primarily used in PUT and PATCH operations
/// where a value may be partially edited and needs to be compared or merged
/// with an existing value from the backend.
extension ValueMerge<T> on T? {
  /// Returns the edited value if it is not `null`,
  /// otherwise falls back to the existing value.
  ///
  /// ### Typical use case (PUT)
  /// When sending a full update payload, this ensures that:
  /// - Edited values take precedence
  /// - Unedited fields retain their existing values
  ///
  /// ```dart
  /// title: form.title.orExisting(existing.title),
  /// ```
  T? orExisting(T? existing) => this ?? existing;

  /// Returns `true` if the edited value is different from the existing value.
  ///
  /// ### Typical use case (PATCH)
  /// Used to determine whether a field should be included in a PATCH payload.
  /// Only fields that return `true` should be sent to the backend.
  ///
  /// ```dart
  /// selectedCity: form.selectedCity.isChangedFrom(existing.selectedCity)
  ///     ? form.selectedCity
  ///     : null,
  /// ```
  bool isChangedFrom(T? existing) => this != existing;
}
