/// Arabic counted nouns.
///
/// Arabic does not pluralise by adding an s: one takes the singular, two takes
/// a dual form, three to ten take the plural, and eleven upwards go back to the
/// singular. A literal `'$n نقطة'` is therefore wrong in three of the four
/// cases, and «1 تفاعلات» reads as machine-written to anyone who speaks the
/// language.
///
/// These live here rather than on a screen because the same counts appear on
/// the rewards page, the account card and the level cards — and because the
/// server says them too, in `PointsRules::pointsLabel()`.
library;

/// «نقطة واحدة / نقطتان / 5 نقاط / 15 نقطة»
String arabicPoints(int n) => _counted(n, 'نقطة واحدة', 'نقطتان', 'نقاط', 'نقطة');

/// «تفاعل واحد / تفاعلان / 5 تفاعلات / 15 تفاعلاً»
String arabicInteractions(int n) =>
    _counted(n, 'تفاعل واحد', 'تفاعلان', 'تفاعلات', 'تفاعلاً');

/// «يوم واحد / يومان / 5 أيام / 30 يوماً»
String arabicDays(int n) => _counted(n, 'يوم واحد', 'يومان', 'أيام', 'يوماً');

String _counted(int n, String one, String two, String few, String many) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n >= 3 && n <= 10) return '$n $few';
  return '$n $many';
}
