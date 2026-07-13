/// Prefixes a doctor's name with "Dr." unless it already starts with one
/// (e.g. "Dr. Sharma", "DR SHARMA", "dr.sharma") to avoid "Dr. Dr. Sharma".
String doctorDisplayName(String? name, {String fallback = 'Doctor'}) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;
  // Requires a dot and/or whitespace after "dr" so real names like
  // "Drake" or "Drishti" aren't mistaken for an existing "Dr" prefix.
  final alreadyPrefixed = RegExp(r'^dr(\.\s*|\s+)', caseSensitive: false);
  if (alreadyPrefixed.hasMatch(trimmed)) return trimmed;
  return 'Dr. $trimmed';
}
