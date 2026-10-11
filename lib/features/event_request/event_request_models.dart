import 'dart:convert';

import 'package:flutter/material.dart';

/// The customer's «نظّم مناسبتك» request.
///
/// This replaces the old "أعلن معنا" card, which opened WhatsApp with a single
/// canned sentence and left the customer to describe their entire event by
/// hand — and left the team to chase the same six questions every time. Asking
/// them here means the first message the team receives is already complete, and
/// the customer gets something back: a tracked request with a progress map.

/// Pins "today" for the countdown on the status screen. The screen says how
/// many days are left until the event, so a golden of it changes every
/// midnight; a render test sets this to a fixed day and the image holds.
@visibleForTesting
DateTime? debugEventRequestToday;

// ---------------------------------------------------------------------------
// EVENT KIND
// ---------------------------------------------------------------------------

enum EventKind { wedding, engagement, katbKtab, graduation, opening, other }

extension EventKindX on EventKind {
  String get label => switch (this) {
        EventKind.wedding => 'زفاف',
        EventKind.engagement => 'خطبة',
        EventKind.katbKtab => 'كتب كتاب',
        EventKind.graduation => 'تخرّج',
        EventKind.opening => 'افتتاح',
        EventKind.other => 'أخرى',
      };

  IconData get icon => switch (this) {
        EventKind.wedding => Icons.favorite_rounded,
        EventKind.engagement => Icons.diamond_rounded,
        EventKind.katbKtab => Icons.menu_book_rounded,
        EventKind.graduation => Icons.school_rounded,
        EventKind.opening => Icons.storefront_rounded,
        EventKind.other => Icons.more_horiz_rounded,
      };
}

// ---------------------------------------------------------------------------
// BUDGET LEVEL
// ---------------------------------------------------------------------------

/// How lavish the event should be. Deliberately not a number: most people can
/// say "متوسطة" long before they can name a figure, and the team reads this to
/// pick which shops to suggest.
enum BudgetLevel { low, medium, high }

extension BudgetLevelX on BudgetLevel {
  String get label => switch (this) {
        BudgetLevel.low => 'منخفضة',
        BudgetLevel.medium => 'متوسطة',
        BudgetLevel.high => 'مرتفعة',
      };

  String get hint => switch (this) {
        BudgetLevel.low => 'الأساسيات بأفضل سعر',
        BudgetLevel.medium => 'توازن بين السعر والجودة',
        BudgetLevel.high => 'أفخم الخيارات المتاحة',
      };

  /// Number of filled stars drawn on the chip.
  int get stars => switch (this) {
        BudgetLevel.low => 1,
        BudgetLevel.medium => 2,
        BudgetLevel.high => 3,
      };
}

// ---------------------------------------------------------------------------
// GUEST COUNT
// ---------------------------------------------------------------------------

/// Ranges rather than a free number: a hall is booked by capacity band, and
/// nobody knows their exact guest count this early.
enum GuestRange { upTo100, upTo200, upTo400, upTo700, above700 }

extension GuestRangeX on GuestRange {
  String get label => switch (this) {
        GuestRange.upTo100 => 'أقل من 100 مدعو',
        GuestRange.upTo200 => 'من 100 إلى 200',
        GuestRange.upTo400 => 'من 200 إلى 400',
        GuestRange.upTo700 => 'من 400 إلى 700',
        GuestRange.above700 => 'أكثر من 700',
      };
}

// ---------------------------------------------------------------------------
// PREFERRED CONTACT TIME
// ---------------------------------------------------------------------------

enum ContactTime { morning, afternoon, evening }

extension ContactTimeX on ContactTime {
  String get label => switch (this) {
        ContactTime.morning => 'صباحاً',
        ContactTime.afternoon => 'ظهراً',
        ContactTime.evening => 'مساءً',
      };

  IconData get icon => switch (this) {
        ContactTime.morning => Icons.wb_sunny_rounded,
        ContactTime.afternoon => Icons.wb_twilight_rounded,
        ContactTime.evening => Icons.nights_stay_rounded,
      };
}

// ---------------------------------------------------------------------------
// THE PROGRESS MAP
// ---------------------------------------------------------------------------

/// One line of the «خارطة إنجاز طلبك».
///
/// Mirrors the app's existing task vocabulary (pending / in_progress / done) so
/// these read the same as everything under «خطّطي».
enum StepStatus { pending, inProgress, done }

extension StepStatusX on StepStatus {
  String get label => switch (this) {
        StepStatus.pending => 'لم يبدأ بعد',
        StepStatus.inProgress => 'قيد المتابعة',
        StepStatus.done => 'تم الإنجاز بنجاح',
      };

  String get id => switch (this) {
        StepStatus.pending => 'pending',
        StepStatus.inProgress => 'in_progress',
        StepStatus.done => 'done',
      };

  static StepStatus fromId(String? v) => switch (v) {
        'done' => StepStatus.done,
        'in_progress' => StepStatus.inProgress,
        _ => StepStatus.pending,
      };
}

class RequestStep {
  RequestStep({
    required this.id,
    required this.label,
    required this.icon,
    this.status = StepStatus.pending,
    this.vendorName,
  });

  final String id;
  final String label;
  final IconData icon;
  StepStatus status;

  /// The shop handling this line once one is chosen — «أزهار فرح» etc.
  String? vendorName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.id,
        'vendor': vendorName,
      };

  /// The icon and label come from [defaultSteps]; only the mutable parts are
  /// persisted, so renaming a step later does not strand old saved requests.
  void applyJson(Map<String, dynamic> j) {
    status = StepStatusX.fromId(j['status']?.toString());
    final v = j['vendor']?.toString();
    vendorName = (v == null || v.isEmpty) ? null : v;
  }
}

/// The service lines every event goes through, in the order the team works
/// them. Kept here rather than fetched so the map renders instantly and still
/// works with no connection.
List<RequestStep> defaultSteps() => [
      RequestStep(id: 'hall', label: 'قاعة الأفراح', icon: Icons.location_city_rounded),
      RequestStep(id: 'decor', label: 'تزيين وأزهار', icon: Icons.local_florist_rounded),
      RequestStep(id: 'photo', label: 'التصوير', icon: Icons.photo_camera_rounded),
      RequestStep(id: 'music', label: 'الموسيقى والدي جي', icon: Icons.music_note_rounded),
      RequestStep(id: 'kosha', label: 'الكوشة والديكور', icon: Icons.chair_rounded),
      RequestStep(id: 'food', label: 'ضيافة ومأكولات', icon: Icons.restaurant_rounded),
      RequestStep(id: 'invites', label: 'دعوات إلكترونية', icon: Icons.mail_rounded),
      RequestStep(id: 'cars', label: 'سيارات الزفة', icon: Icons.directions_car_rounded),
      RequestStep(id: 'gifts', label: 'هدايا الضيوف', icon: Icons.card_giftcard_rounded),
      RequestStep(id: 'dress', label: 'الفستان والتجميل', icon: Icons.auto_awesome_rounded),
    ];

// ---------------------------------------------------------------------------
// THE REQUEST
// ---------------------------------------------------------------------------

enum RequestStage { underReview, accepted }

class EventRequest {
  EventRequest({
    required this.kind,
    required this.level,
    required this.cityName,
    required this.date,
    required this.guests,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.contactTime,
    required this.createdAt,
    this.cityId,
    this.notes,
    this.stage = RequestStage.underReview,
    List<RequestStep>? steps,
  }) : steps = steps ?? defaultSteps();

  final EventKind kind;
  final BudgetLevel level;
  final int? cityId;
  final String cityName;
  final DateTime date;
  final GuestRange guests;
  final String fullName;
  final String phone;
  final String address;
  final ContactTime contactTime;
  final String? notes;
  final DateTime createdAt;

  RequestStage stage;
  final List<RequestStep> steps;

  /// A short human reference the customer can quote to the team. Derived from
  /// the creation time so it needs no server round-trip and never collides for
  /// one person's own requests.
  String get reference {
    final ms = createdAt.millisecondsSinceEpoch ~/ 1000;
    return 'AF-${ms.toRadixString(36).toUpperCase()}';
  }

  int get doneCount => steps.where((s) => s.status == StepStatus.done).length;

  /// Percent complete. An in-progress line counts as half: showing 0% while
  /// three shops are actively working reads as "nothing is happening".
  int get progress {
    if (steps.isEmpty) return 0;
    final score = steps.fold<double>(0, (a, s) => a + switch (s.status) {
          StepStatus.done => 1.0,
          StepStatus.inProgress => 0.5,
          StepStatus.pending => 0.0,
        });
    return ((score / steps.length) * 100).round();
  }

  String get dateLabel =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  /// How many days until the event; negative once it has passed.
  int get daysAway {
    final today = debugEventRequestToday ?? DateTime.now();
    return DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  /// The message the team receives. Written as a readable brief rather than a
  /// data dump, because a human reads it first.
  String get teamMessage => [
        'طلب تنظيم مناسبة جديد 🎉',
        'الرقم المرجعي: $reference',
        '',
        '• نوع المناسبة: ${kind.label}',
        '• المستوى: ${level.label}',
        '• المدينة: $cityName',
        '• التاريخ: $dateLabel',
        '• عدد المدعوين: ${guests.label}',
        '',
        '• الاسم: $fullName',
        '• الجوال: $phone',
        '• مكان السكن: $address',
        '• وقت التواصل المفضّل: ${contactTime.label}',
        if ((notes ?? '').trim().isNotEmpty) ...['', '• ملاحظات: ${notes!.trim()}'],
      ].join('\n');

  /// What the customer shares with family — the progress, not their phone
  /// number. Deliberately omits every contact field.
  String get shareMessage => [
        'طلب تنظيم ${kind.label} — أفراحنا',
        'الرقم المرجعي: $reference',
        'التاريخ: $dateLabel · $cityName',
        'نسبة الإنجاز: $progress%',
        '',
        ...steps.map((s) => '${switch (s.status) {
              StepStatus.done => '✅',
              StepStatus.inProgress => '🔄',
              StepStatus.pending => '⬜',
            }} ${s.label}${s.vendorName == null ? '' : ' — ${s.vendorName}'}'),
      ].join('\n');

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'level': level.name,
        'city_id': cityId,
        'city': cityName,
        'date': date.toIso8601String(),
        'guests': guests.name,
        'name': fullName,
        'phone': phone,
        'address': address,
        'contact_time': contactTime.name,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'stage': stage.name,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  static EventRequest? fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      final s = raw?.toString();
      for (final v in values) {
        if (v.name == s) return v;
      }
      return fallback;
    }

    final date = DateTime.tryParse(j['date']?.toString() ?? '');
    final created = DateTime.tryParse(j['created_at']?.toString() ?? '');
    if (date == null || created == null) return null;

    final steps = defaultSteps();
    final saved = j['steps'];
    if (saved is List) {
      for (final raw in saved) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final id = m['id']?.toString();
        for (final s in steps) {
          if (s.id == id) s.applyJson(m);
        }
      }
    }

    return EventRequest(
      kind: pick(EventKind.values, j['kind'], EventKind.wedding),
      level: pick(BudgetLevel.values, j['level'], BudgetLevel.medium),
      cityId: (j['city_id'] as num?)?.toInt(),
      cityName: (j['city'] ?? '').toString(),
      date: date,
      guests: pick(GuestRange.values, j['guests'], GuestRange.upTo200),
      fullName: (j['name'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      contactTime: pick(ContactTime.values, j['contact_time'], ContactTime.evening),
      notes: j['notes']?.toString(),
      createdAt: created,
      stage: pick(RequestStage.values, j['stage'], RequestStage.underReview),
      steps: steps,
    );
  }

  String encode() => jsonEncode(toJson());

  static EventRequest? decode(String raw) {
    try {
      final j = jsonDecode(raw);
      return j is Map ? EventRequest.fromJson(Map<String, dynamic>.from(j)) : null;
    } catch (_) {
      // A malformed blob means a shape change or a partial write; treat it as
      // "no saved request" rather than trapping the customer on a crash.
      return null;
    }
  }
}
