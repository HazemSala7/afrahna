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
    this.weddingPlan = false,
  });

  final String raw;
  final AssistantIntent intent;
  final double? maxBudget;
  final double? minBudget;
  final String? categoryHint;
  final String? cityHint;
  final String? currency;

  /// True when the user asks for a full wedding budget breakdown,
  /// e.g. «ميزانيتي 50000 بدي أتجوز».
  final bool weddingPlan;
}

/// A single line in a wedding budget breakdown.
class WeddingPlanItem {
  WeddingPlanItem({
    required this.label,
    required this.emoji,
    required this.percent,
    required this.allocated,
    this.vendor,
    this.startingPrice,
  });

  final String label;
  final String emoji;
  final double percent;
  final double allocated;
  final VendorModel? vendor;
  final double? startingPrice;
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
    this.plan = const [],
    this.planBudget,
  });

  final String reply;
  final List<VendorModel> vendors;
  final Map<int, double?> minPriceByVendor;
  final CategoryModel? matchedCategory;
  final CityModel? matchedCity;
  final AssistantQuery? query;

  /// Wedding budget breakdown (empty for normal queries).
  final List<WeddingPlanItem> plan;
  final double? planBudget;
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
  static const _weddingWords = [
    'اتجوز', 'أتجوز', 'اتزوج', 'أتزوج', 'جواز', 'زواج', 'عرس', 'عرسي',
    'زفاف', 'فرح', 'فرحي', 'حفل زفاف', 'حفلة زفاف', 'كل اشي للعرس',
    'خطط للعرس', 'خطه للعرس', 'تجهيز عرس', 'تجهيزات العرس', 'wedding',
  ];
  // "Split / divide / distribute my budget" phrasing → also a wedding plan.
  static const _splitWords = [
    'قسم', 'قسملي', 'قسملي', 'قسمها', 'قسمهم', 'تقسيم', 'وزع', 'وزعلي',
    'وزعها', 'توزيع', 'فرقها', 'فصلها', 'رتبلي', 'رتبهم', 'خطه', 'خطة',
    'ميزانيتي', 'ميزانيه', 'ميزانية', 'split', 'divide', 'distribute',
    'breakdown', 'break down', 'budget', 'plan',
  ];
  // "I have / what if I have X" possession phrasing.
  static const _haveWords = [
    'معي', 'عندي', 'بيدي', 'صار معي', 'لو معي', 'اذا معي', 'إذا معي',
    'لو عندي', 'اذا عندي', 'ماذا لو', 'i have', 'if i have', 'what if i have',
    'i got', 'got', 'have',
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

  /// Public normalizer reused by the engine's wedding planner.
  static String normalize(String s) => _normalize(s);

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
    if (_contains(t, _cheapWords)) {
      intent = AssistantIntent.cheapest;
    } else if (_contains(t, _bestWords)) {
      intent = AssistantIntent.best;
    }

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

    final weddingPlan = _contains(t, _weddingWords) ||
        (amount != null &&
            (_contains(t, _splitWords) || _contains(t, _haveWords)));

    return AssistantQuery(
      raw: raw,
      intent: intent,
      maxBudget: maxBudget,
      minBudget: minBudget,
      categoryHint: categoryHint,
      cityHint: cityHint,
      currency: currency,
      weddingPlan: weddingPlan,
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

  Future<void> _ensureLoaded() async {
    final missing = _cats == null || _cities == null || _vendors == null;
    if (!missing) return;
    // Only three lightweight calls; vendor.minPrice/maxPrice already come from
    // the API, so we avoid the heavy unpaginated /services endpoint entirely.
    final results = await Future.wait([
      CategoryService().list(),
      CityService().list(),
      VendorService().list(perPage: 100),
    ]);
    _cats = results[0] as List<CategoryModel>;
    _cities = results[1] as List<CityModel>;
    _vendors = results[2] as List<VendorModel>;
  }

  /// Warms up the in-memory caches so the first question answers instantly.
  /// Safe to call repeatedly and ignores network errors during warmup.
  Future<void> preload() async {
    try {
      await _ensureLoaded();
    } catch (_) {
      // ignored — the next ask() will retry and surface any error
    }
  }

  Future<AssistantResult> ask(String text) async {
    final q = AssistantQueryParser.parse(text);
    await _ensureLoaded();
    final cats = _cats ?? const <CategoryModel>[];
    final cities = _cities ?? const <CityModel>[];
    final allVendors = _vendors ?? const <VendorModel>[];

    final cat = AssistantQueryParser.matchCategory(q.categoryHint, cats);
    final city = AssistantQueryParser.matchCity(q.cityHint, cities);

    // Cheapest known price for a vendor, straight from the API fields.
    double minPriceOf(VendorModel v) => v.minPrice ?? double.infinity;

    // ── Wedding budget breakdown (ChatGPT-style plan) ──────────────────
    if (q.weddingPlan) {
      return _buildWeddingPlan(
        query: q,
        cats: cats,
        city: city,
        vendors: allVendors,
        minPriceOf: minPriceOf,
      );
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
        final mp = v.minPrice;
        return mp == null || mp <= q.maxBudget! + 0.0001;
      });
    }
    if (q.minBudget != null) {
      filtered = filtered.where((v) {
        final mp = v.maxPrice ?? v.minPrice;
        return mp == null || mp >= q.minBudget! - 0.0001;
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

    double minPrice(VendorModel v) => v.minPrice ?? double.infinity;

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

  /// Wedding plan slots: label, emoji, category keyword matchers and the
  /// default share of the total budget. Shares sum to 1.0.
  static const _planSlots = <({
    String label,
    String emoji,
    List<String> keywords,
    double share,
  })>[
    (label: 'قاعة الأفراح', emoji: '🏛️', share: 0.32, keywords: [
      'قاعه', 'قاعات', 'صاله', 'صالات', 'منتجع', 'حديقه', 'مزرعه', 'فندق',
    ]),
    (label: 'التصوير والفيديو', emoji: '📸', share: 0.15, keywords: [
      'تصوير', 'مصور', 'فوتو', 'فيديو', 'كاميرا', 'استوديو', 'فوتوغراف',
    ]),
    (label: 'التنسيق والكوش', emoji: '💐', share: 0.13, keywords: [
      'تنسيق', 'كوش', 'كوشه', 'ديكور', 'ورد', 'زهور', 'اضاءه', 'فلاور',
    ]),
    (label: 'فستان الزفاف', emoji: '👰', share: 0.12, keywords: [
      'فستان', 'فساتين', 'بدله', 'بدلات', 'عبايه', 'ازياء',
    ]),
    (label: 'المكياج والتجميل', emoji: '💄', share: 0.08, keywords: [
      'مكياج', 'ميكب', 'تجميل', 'كوافير', 'صالون', 'شعر', 'بيوتي',
    ]),
    (label: 'الموسيقى والزفّة', emoji: '🎶', share: 0.08, keywords: [
      'dj', 'دي جي', 'زفه', 'زفات', 'فرقه', 'طبل', 'موسيقى', 'اوركسترا',
    ]),
    (label: 'الضيافة والحلويات', emoji: '🍰', share: 0.09, keywords: [
      'ضيافه', 'حلويات', 'كيك', 'كاترينج', 'بوفيه', 'مأكولات', 'طعام', 'حلى',
    ]),
    (label: 'الدعوات والكروت', emoji: '✉️', share: 0.03, keywords: [
      'دعوات', 'كروت', 'بطاقات', 'invitation', 'دعوه',
    ]),
  ];

  /// Builds a full wedding budget breakdown across the main categories,
  /// recommending the best-rated vendor that fits each allocated slice.
  AssistantResult _buildWeddingPlan({
    required AssistantQuery query,
    required List<CategoryModel> cats,
    required CityModel? city,
    required List<VendorModel> vendors,
    required double Function(VendorModel) minPriceOf,
  }) {
    final total = query.maxBudget ?? query.minBudget;

    // Pre-filter vendors by city when the user mentioned one.
    final pool = city == null
        ? vendors
        : vendors.where((v) => v.cityId == city.id).toList();

    final items = <WeddingPlanItem>[];
    final picked = <VendorModel>[];
    final minMap = <int, double?>{};
    final usedVendorIds = <int>{};

    for (final slot in _planSlots) {
      // category ids whose name matches any of the slot keywords
      final catIds = <int>{};
      for (final c in cats) {
        final name = AssistantQueryParser.normalize('${c.nameAr} ${c.nameEn}');
        if (slot.keywords.any((k) =>
            name.contains(AssistantQueryParser.normalize(k)))) {
          catIds.add(c.id);
        }
      }

      final allocated = total == null ? 0.0 : total * slot.share;

      // candidate vendors for this slot
      final candidates = pool
          .where((v) =>
              v.categoryId != null &&
              catIds.contains(v.categoryId) &&
              !usedVendorIds.contains(v.id))
          .toList();

      VendorModel? chosen;
      double? startPrice;
      if (candidates.isNotEmpty) {
        int byRating(VendorModel a, VendorModel b) {
          final cmp = (b.rating ?? 0).compareTo(a.rating ?? 0);
          if (cmp != 0) return cmp;
          return (b.reviewsCount ?? 0).compareTo(a.reviewsCount ?? 0);
        }

        // Prefer vendors whose cheapest service fits the slice, ranked by rating.
        final affordable = candidates.where((v) {
          final mp = minPriceOf(v);
          return !mp.isFinite || total == null || mp <= allocated + 0.0001;
        }).toList()
          ..sort(byRating);

        chosen = affordable.isNotEmpty
            ? affordable.first
            : (candidates
              ..sort((a, b) => minPriceOf(a).compareTo(minPriceOf(b)))).first;

        final mp = minPriceOf(chosen);
        startPrice = mp.isFinite ? mp : null;
        usedVendorIds.add(chosen.id);
        picked.add(chosen);
        minMap[chosen.id] = startPrice;
      }

      items.add(WeddingPlanItem(
        label: slot.label,
        emoji: slot.emoji,
        percent: slot.share,
        allocated: allocated,
        vendor: chosen,
        startingPrice: startPrice,
      ));
    }

    final reply = _buildPlanReply(
      city: city,
      total: total,
      items: items,
    );

    return AssistantResult(
      reply: reply,
      vendors: picked,
      minPriceByVendor: minMap,
      matchedCity: city,
      query: query,
      plan: items,
      planBudget: total,
    );
  }

  String _buildPlanReply({
    required CityModel? city,
    required double? total,
    required List<WeddingPlanItem> items,
  }) {
    final where = city != null ? ' في ${city.nameAr}' : '';
    final found = items.where((e) => e.vendor != null).length;
    final sb = StringBuffer();
    if (total != null) {
      sb.write('تمام 🎉 إليك خطة عرسك$where بميزانية '
          '${_fmtFull(total)} ₪، موزّعة على أهم البنود:');
    } else {
      sb.write('تمام 🎉 إليك خطة تجهيز عرسك$where بأهم البنود. '
          'أخبرني بميزانيتك لأقسّمها لك بالأرقام:');
    }
    if (found == 0) {
      sb.write('\n\nما لقيت معلنين مطابقين حالياً — جرّب توسيع المدينة '
          'أو اسأل عن فئة محددة 🙂');
    } else {
      sb.write('\n\nاخترت لك أفضل خيار ضمن كل بند حسب التقييم والسعر. '
          'اضغط على أي بطاقة لمزيد من التفاصيل 👇');
    }
    return sb.toString();
  }

  static String _fmtFull(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
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
    'ميزانيتي 50000 وبدي أتجوز، قسّملي المصاريف',
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
