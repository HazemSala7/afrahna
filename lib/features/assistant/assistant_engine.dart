import 'dart:math' as math;

import '../../core/models/models.dart';
import '../../core/services/services.dart';

/// What the user is asking for.
enum AssistantIntent { best, cheapest, list }

/// Parsed intent extracted from an Arabic free-form query.
class AssistantQuery {
  AssistantQuery({
    required this.raw,
    required this.intent,
    this.maxBudget,
    this.minBudget,
    this.categoryHint,
    this.cityHint,
    this.currency,
  });

  final String raw;
  final AssistantIntent intent;
  final double? maxBudget;
  final double? minBudget;
  final String? categoryHint;
  final String? cityHint;
  final String? currency;
}

/// Result returned by the engine for a single user turn.
class AssistantResult {
  AssistantResult({
    required this.reply,
    required this.vendors,
    required this.minPriceByVendor,
    this.matchedCategory,
    this.matchedCity,
    this.query,
  });

  final String reply;
  final List<VendorModel> vendors;
  final Map<int, double?> minPriceByVendor;
  final CategoryModel? matchedCategory;
  final CityModel? matchedCity;
  final AssistantQuery? query;
}

/// ===========================================================================
/// PARSER — extracts intent / budget / category / city from Arabic text.
/// ===========================================================================
class AssistantQueryParser {
  static const _bestWords = [
    'افضل', 'أفضل', 'احسن', 'أحسن', 'اعلى تقييم', 'أعلى تقييم',
    'الاعلى', 'الأعلى', 'اشهر', 'أشهر', 'top', 'best',
  ];
  static const _cheapWords = [
    'ارخص', 'أرخص', 'اقل سعر', 'أقل سعر', 'اوفر', 'أوفر',
    'cheap', 'cheapest',
  ];
  static const _maxWords = [
    'ماكسيمم', 'ماكس', 'بحد اقصى', 'بحد أقصى', 'حد اقصى', 'حد أقصى',
    'اقل من', 'أقل من', 'تحت', 'حتى', 'لا يتجاوز', 'max',
  ];
  static const _minWords = [
    'فوق', 'اكثر من', 'أكثر من', 'ابتداء من', 'ابتدأ من', 'فأكثر',
    'على الاقل', 'على الأقل', 'min',
  ];

  static String _normalize(String s) {
    var t = s.trim().toLowerCase();
    // unify Arabic alef variants
    t = t
        .replaceAll(RegExp('[إأآا]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp('[ًٌٍَُِّْ]'), '');
    // Arabic-Indic digits → western digits
    const ar = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    for (var i = 0; i < ar.length; i++) {
      t = t.replaceAll(ar[i], '$i');
    }
    return t;
  }

  static bool _contains(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(_normalize(n))) return true;
    }
    return false;
  }

  /// Detect a number followed by (or preceded by) a currency word.
  static ({double amount, String? currency})? _extractAmount(String text) {
    final reg = RegExp(
      r'(\d{2,7})\s*(شيكل|شيقل|ش\.ج|₪|دولار|usd|\$|دينار|jod|jd)?',
      caseSensitive: false,
    );
    final m = reg.firstMatch(text);
    if (m == null) return null;
    return (amount: double.parse(m.group(1)!), currency: m.group(2));
  }

  static AssistantQuery parse(String raw) {
    final t = _normalize(raw);

    AssistantIntent intent = AssistantIntent.list;
    if (_contains(t, _cheapWords)) intent = AssistantIntent.cheapest;
    else if (_contains(t, _bestWords)) intent = AssistantIntent.best;

    double? maxBudget;
    double? minBudget;
    String? currency;
    final amount = _extractAmount(t);
    if (amount != null) {
      currency = amount.currency;
      if (_contains(t, _maxWords)) {
        maxBudget = amount.amount;
      } else if (_contains(t, _minWords)) {
        minBudget = amount.amount;
      } else {
        // any amount with no qualifier → treat as max budget
        maxBudget = amount.amount;
      }
    }

    // category hint = everything after we strip stop-words
    final categoryHint = t;
    String? cityHint;
    final cityMatch = RegExp(r'في\s+([\u0600-\u06FFa-z\s]{2,30})').firstMatch(t);
    if (cityMatch != null) cityHint = cityMatch.group(1)!.trim();

    return AssistantQuery(
      raw: raw,
      intent: intent,
      maxBudget: maxBudget,
      minBudget: minBudget,
      categoryHint: categoryHint,
      cityHint: cityHint,
      currency: currency,
    );
  }

  /// Best category match by simple substring + token overlap.
  static CategoryModel? matchCategory(
      String? hint, List<CategoryModel> all) {
    if (hint == null || all.isEmpty) return null;
    final h = _normalize(hint);
    CategoryModel? best;
    int bestScore = 0;
    for (final c in all) {
      final names = [_normalize(c.nameAr), _normalize(c.nameEn)];
      int score = 0;
      for (final n in names) {
        if (n.isEmpty) continue;
        if (h.contains(n)) score += 5;
        for (final tok in n.split(RegExp(r'\s+'))) {
          if (tok.length >= 3 && h.contains(tok)) score += 2;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return bestScore >= 2 ? best : null;
  }

  static CityModel? matchCity(String? hint, List<CityModel> all) {
    if (hint == null || all.isEmpty) return null;
    final h = _normalize(hint);
    for (final c in all) {
      final n = _normalize(c.nameAr);
      if (n.isEmpty) continue;
      if (h.contains(n)) return c;
    }
    return null;
  }
}

/// ===========================================================================
/// ENGINE — orchestrates API calls + ranking + natural-language reply.
/// ===========================================================================
class AssistantEngine {
  AssistantEngine();

  // simple in-memory caches per app run
  List<CategoryModel>? _cats;
  List<CityModel>? _cities;
  List<VendorModel>? _vendors;
  List<ServiceModel>? _services;

  Future<void> _ensureLoaded() async {
    final missing = _cats == null ||
        _cities == null ||
        _vendors == null ||
        _services == null;
    if (!missing) return;
    final results = await Future.wait([
      CategoryService().list(),
      CityService().list(),
      VendorService().list(),
      ServiceService().list(),
    ]);
    _cats = results[0] as List<CategoryModel>;
    _cities = results[1] as List<CityModel>;
    _vendors = results[2] as List<VendorModel>;
    _services = results[3] as List<ServiceModel>;
  }

  Future<AssistantResult> ask(String text) async {
    final q = AssistantQueryParser.parse(text);
    await _ensureLoaded();

    final cats = _cats ?? const <CategoryModel>[];
    final cities = _cities ?? const <CityModel>[];
    final allVendors = _vendors ?? const <VendorModel>[];
    final allServices = _services ?? const <ServiceModel>[];

    final cat = AssistantQueryParser.matchCategory(q.categoryHint, cats);
    final city = AssistantQueryParser.matchCity(q.cityHint, cities);

    // services grouped by vendor
    final byVendor = <int, List<ServiceModel>>{};
    for (final s in allServices) {
      final id = s.vendorId;
      if (id != null) byVendor.putIfAbsent(id, () => []).add(s);
    }

    Iterable<VendorModel> filtered = allVendors;
    if (cat != null) {
      filtered = filtered.where((v) => v.categoryId == cat.id);
    }
    if (city != null) {
      filtered = filtered.where((v) => v.cityId == city.id);
    }
    if (q.maxBudget != null) {
      filtered = filtered.where((v) {
        final svc = byVendor[v.id];
        if (svc == null || svc.isEmpty) return true;
        return svc.any((s) =>
            s.price == null || s.price! <= q.maxBudget! + 0.0001);
      });
    }
    if (q.minBudget != null) {
      filtered = filtered.where((v) {
        final svc = byVendor[v.id];
        if (svc == null || svc.isEmpty) return true;
        return svc.any((s) =>
            s.price == null || s.price! >= q.minBudget! - 0.0001);
      });
    }

    final list = filtered.toList();

    int byRating(VendorModel a, VendorModel b) {
      final ra = (a.rating ?? 0);
      final rb = (b.rating ?? 0);
      final cmp = rb.compareTo(ra);
      if (cmp != 0) return cmp;
      return (b.reviewsCount ?? 0).compareTo(a.reviewsCount ?? 0);
    }

    double minPrice(VendorModel v) {
      final svc = byVendor[v.id] ?? const <ServiceModel>[];
      double m = double.infinity;
      for (final s in svc) {
        final p = s.price;
        if (p != null && p < m) m = p;
      }
      return m;
    }

    switch (q.intent) {
      case AssistantIntent.cheapest:
        list.sort((a, b) => minPrice(a).compareTo(minPrice(b)));
        break;
      case AssistantIntent.best:
      case AssistantIntent.list:
        list.sort(byRating);
        break;
    }

    final top = list.take(5).toList();
    final minMap = <int, double?>{};
    for (final v in top) {
      final mp = minPrice(v);
      minMap[v.id] = mp.isFinite ? mp : null;
    }

    final reply = _buildReply(
      query: q,
      cat: cat,
      city: city,
      results: top,
      totalMatched: list.length,
      minPrice: (v) => minMap[v.id],
    );

    return AssistantResult(
      reply: reply,
      vendors: top,
      minPriceByVendor: minMap,
      matchedCategory: cat,
      matchedCity: city,
      query: q,
    );
  }

  String _buildReply({
    required AssistantQuery query,
    required CategoryModel? cat,
    required CityModel? city,
    required List<VendorModel> results,
    required int totalMatched,
    required double? Function(VendorModel) minPrice,
  }) {
    if (results.isEmpty) {
      final parts = <String>['ما لقيت نتائج مطابقة'];
      if (cat != null) parts.add('لفئة «${cat.nameAr}»');
      if (city != null) parts.add('في ${city.nameAr}');
      if (query.maxBudget != null) {
        parts.add('بسعر تحت ${_fmt(query.maxBudget!)} ${query.currency ?? "₪"}');
      }
      return '${parts.join(' ')}. جرّب توسيع شروط البحث 🙂';
    }

    final intentWord = switch (query.intent) {
      AssistantIntent.cheapest => 'الأوفر سعراً',
      AssistantIntent.best => 'الأعلى تقييماً',
      AssistantIntent.list => 'الأنسب',
    };

    final what = cat != null ? cat.nameAr : 'المعلنين';
    final where = city != null ? ' في ${city.nameAr}' : '';
    final budgetLine = query.maxBudget != null
        ? ' ضمن ميزانية ${_fmt(query.maxBudget!)} ${query.currency ?? "₪"}'
        : '';

    final first = results.first;
    final firstPrice = minPrice(first);
    final firstRating = first.rating;
    final mention = StringBuffer()
      ..write('أنصحك بـ «${first.name}»');
    if (firstRating != null) {
      mention.write(' بتقييم ${firstRating.toStringAsFixed(1)}/5');
    }
    if (firstPrice != null) {
      mention.write(' وأرخص خدمة لديه ${_fmt(firstPrice)} ₪');
    }
    mention.write('.');

    return 'تمام! إليك $intentWord من $what$where$budgetLine. '
        'لقيت ${results.length} نتيجة من أصل $totalMatched. $mention';
  }

  static String _fmt(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      final s = k == k.roundToDouble() ? k.toInt().toString() : k.toStringAsFixed(1);
      return '${s}K';
    }
    return v.toStringAsFixed(0);
  }

  /// Suggested starter questions to show on the empty state.
  static const suggestions = <String>[
    'بدي أفضل خدمة تصوير',
    'أفضل قاعة أعراس بميزانية 5000 شيكل',
    'أرخص منسق ورد في رام الله',
    'بدي DJ بحد أقصى 2000 شيكل',
  ];

  // intentionally unused helper kept for future ranking weights
  // ignore: unused_element
  static double _normalize(double x, double max) =>
      max <= 0 ? 0 : math.min(1, x / max);
}
