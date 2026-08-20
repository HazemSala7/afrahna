// All data models for the Afrahna app.
// Bilingual fields (ar/en) map to the corresponding columns in the Laravel API.

import 'dart:convert';

import '../rewards_ladder.dart';

T? _readT<T>(Map<String, dynamic> json, String key) =>
    json[key] is T ? json[key] as T : null;

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// Parses a list of strings from a JSON array (or a JSON-encoded string).
List<String> _toStringList(dynamic v) {
  if (v == null) return const [];
  if (v is List) {
    return v
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (v is String && v.trim().startsWith('[')) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) return _toStringList(decoded);
    } catch (_) {}
  }
  return const [];
}

// ---------------------------------------------------------------------------
// USER
// ---------------------------------------------------------------------------

class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.role,
    this.avatar,
    this.isActive = true,
    this.delegateId,
    this.workField,
    this.cityId,
    this.commissionPerSubscription,
    this.permissions = const {},
    this.vendorName,
    this.vendorLogo,
    this.activePlan,
    this.notificationsEnabled = true,
    this.pointsBalance = 0,
    this.pointsPerShekel = 10,
    this.rewardsTaken = 0,
    this.referralCode,
    this.whatsapp,
    this.instagram,
    this.facebook,
    this.tiktok,
    this.snapchat,
    this.createdAt,
  });

  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? role;
  final String? avatar;
  final bool isActive;
  final int? delegateId;
  final String? workField;
  final int? cityId;
  final double? commissionPerSubscription;

  /// Granular delegate permission map, e.g. {'edit_vendor': true}.
  final Map<String, dynamic> permissions;

  /// Name of the shop (vendor) this user owns, when the API eager-loads it
  /// (e.g. the delegate's clients list). Null if the user has no shop.
  final String? vendorName;

  /// Logo URL of the user's shop, when available.
  final String? vendorLogo;

  /// Current active subscription plan key (normal|featured|vip), or null when
  /// the client has no active subscription. Provided by the delegate clients list.
  final String? activePlan;

  /// Whether the user receives notifications (offer alerts, etc.). Can be
  /// toggled off from the app. Defaults to true.
  final bool notificationsEnabled;

  /// Rewards points balance available to spend.
  final int pointsBalance;

  /// Points that equal one shekel, sent by the server so the rate can be
  /// retuned from the dashboard without shipping a new build.
  final int pointsPerShekel;

  /// How many 50 ₪ rewards this member has cashed out. It — not the balance —
  /// is what decides the level: claiming a reward spends the balance back down
  /// to near zero, so a balance-based tier would demote everyone the moment
  /// they were paid.
  final int rewardsTaken;

  /// The balance expressed in shekels, read off the member's own rung: a full
  /// goal pays [RewardsLadder.rewardIls], so 100 points is 50 ₪ at برونزي.
  ///
  /// Derived here rather than from [pointsPerShekel] so the account card and
  /// the rewards screen can never quote two different prices for one point —
  /// they did, briefly, and «تساوي 6.30 ₪» beside «باقي 137 نقطة على 50 شيكل»
  /// is the kind of thing that reads as a bug even when both numbers are
  /// individually defensible.
  double get pointsValueIls {
    final goal = RewardsLadder.goalFor(rewardsTaken);
    return goal <= 0 ? 0 : pointsBalance * RewardsLadder.rewardIls / goal;
  }

  /// Money value formatted for display, e.g. «2.5 ₪».
  String get pointsValueLabel {
    final v = pointsValueIls;
    return '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)} ₪';
  }

  /// The user's own invite/referral code (share it to earn invite points).
  final String? referralCode;

  /// Personal social handles, editable from the profile screen.
  final String? whatsapp;
  final String? instagram;
  final String? facebook;
  final String? tiktok;
  final String? snapchat;

  /// When the account was created — shown as "عضو منذ".
  final DateTime? createdAt;

  /// The rung of the rewards ladder this member stands on.
  ///
  /// It used to be read off the balance (100 → فضي, 500 → ذهبي, 1000 → ماسي),
  /// which had two problems once the ladder became real: «ماسي» is not a level
  /// that exists, and a member who cashed out dropped a tier for having been
  /// paid. Both now come from [rewardsTaken], the same number the server uses.
  String get tierLabel => RewardsLadder.rungFor(rewardsTaken).name;

  /// «المستوى 3» — keeps counting past بلاتيني.
  int get tierLevel => RewardsLadder.levelFor(rewardsTaken);

  /// Points this level asks for before it pays out.
  int get tierGoal => RewardsLadder.goalFor(rewardsTaken);

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: _toInt(json['id']) ?? 0,
        name: (json['name'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        email: _readT<String>(json, 'email'),
        role: _readT<String>(json, 'role'),
        avatar: _readT<String>(json, 'avatar'),
        isActive: json['is_active'] == null
            ? true
            : (json['is_active'] == true || json['is_active'] == 1),
        delegateId: _toInt(json['delegate_id']),
        workField: _readT<String>(json, 'work_field'),
        cityId: _toInt(json['city_id']),
        commissionPerSubscription: _toDouble(json['commission_per_subscription']),
        permissions: json['permissions'] is Map
            ? Map<String, dynamic>.from(json['permissions'] as Map)
            : const {},
        vendorName: json['vendor'] is Map
            ? (_readT<String>(
                    Map<String, dynamic>.from(json['vendor'] as Map), 'name_ar') ??
                _readT<String>(
                    Map<String, dynamic>.from(json['vendor'] as Map), 'name_en'))
            : null,
        vendorLogo: json['vendor'] is Map
            ? _readT<String>(
                Map<String, dynamic>.from(json['vendor'] as Map), 'logo')
            : null,
        activePlan: _readT<String>(json, 'active_plan'),
        notificationsEnabled: json['notifications_enabled'] == null
            ? true
            : (json['notifications_enabled'] == true ||
                json['notifications_enabled'] == 1),
        pointsBalance: _toInt(json['points_balance']) ?? 0,
        pointsPerShekel: _toInt(json['points_per_shekel']) ?? 10,
        rewardsTaken: _toInt(json['rewards_taken']) ?? 0,
        referralCode: _readT<String>(json, 'referral_code'),
        whatsapp: _readT<String>(json, 'whatsapp'),
        instagram: _readT<String>(json, 'instagram'),
        facebook: _readT<String>(json, 'facebook'),
        tiktok: _readT<String>(json, 'tiktok'),
        snapchat: _readT<String>(json, 'snapchat'),
        createdAt: _toDate(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role,
        'avatar': avatar,
        'is_active': isActive,
        'delegate_id': delegateId,
        'work_field': workField,
        'city_id': cityId,
        'commission_per_subscription': commissionPerSubscription,
        'permissions': permissions,
        'notifications_enabled': notificationsEnabled,
        'points_balance': pointsBalance,
        'points_per_shekel': pointsPerShekel,
        'rewards_taken': rewardsTaken,
        'referral_code': referralCode,
      };

  UserModel copyWith({bool? notificationsEnabled}) => UserModel(
        id: id,
        name: name,
        phone: phone,
        email: email,
        role: role,
        avatar: avatar,
        isActive: isActive,
        delegateId: delegateId,
        workField: workField,
        cityId: cityId,
        commissionPerSubscription: commissionPerSubscription,
        permissions: permissions,
        vendorName: vendorName,
        vendorLogo: vendorLogo,
        activePlan: activePlan,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        pointsBalance: pointsBalance,
        pointsPerShekel: pointsPerShekel,
        rewardsTaken: rewardsTaken,
        referralCode: referralCode,
        whatsapp: whatsapp,
        instagram: instagram,
        facebook: facebook,
        tiktok: tiktok,
        snapchat: snapchat,
        createdAt: createdAt,
      );

  bool get isVendor   => role == 'vendor';
  bool get isAdmin    => role == 'admin';
  bool get isCustomer => role == 'customer';
  bool get isDelegate => role == 'delegate';

  /// Admins implicitly have every permission; delegates check the map.
  bool hasPermission(String key) {
    if (isAdmin) return true;
    final v = permissions[key];
    return v == true || v == 1 || v == '1';
  }
}

// ---------------------------------------------------------------------------
// CITY
// ---------------------------------------------------------------------------

class CityModel {
  CityModel({required this.id, required this.nameAr, required this.nameEn});

  final int id;
  final String nameAr;
  final String nameEn;

  String get name => nameAr.isNotEmpty ? nameAr : nameEn;

  factory CityModel.fromJson(Map<String, dynamic> json) => CityModel(
        id: _toInt(json['id']) ?? 0,
        nameAr: (json['name_ar'] ?? json['name'] ?? '').toString(),
        nameEn: (json['name_en'] ?? '').toString(),
      );
}

// ---------------------------------------------------------------------------
// CATEGORY
// ---------------------------------------------------------------------------

class CategoryModel {
  CategoryModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.icon,
    this.slug,
    this.parentId,
    this.children = const [],
  });

  final int id;
  final String nameAr;
  final String nameEn;
  final String? icon;
  final String? slug;
  final int? parentId;
  final List<CategoryModel> children;

  String get name => nameAr.isNotEmpty ? nameAr : nameEn;
  bool get hasChildren => children.isNotEmpty;

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: _toInt(json['id']) ?? 0,
        nameAr: (json['name_ar'] ?? json['name'] ?? '').toString(),
        nameEn: (json['name_en'] ?? '').toString(),
        icon: _readT<String>(json, 'icon'),
        slug: _readT<String>(json, 'slug'),
        parentId: _toInt(json['parent_id']),
        children: (json['children'] is List)
            ? (json['children'] as List)
                .whereType<Map>()
                .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );
}

// ---------------------------------------------------------------------------
// VENDOR
// ---------------------------------------------------------------------------

class VendorModel {
  VendorModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    this.logo,
    this.cover,
    this.cityId,
    this.categoryId,
    this.city,
    this.category,
    this.rating,
    this.reviewsCount,
    this.viewsCount = 0,
    this.phone,
    this.address,
    this.whatsapp,
    this.instagram,
    this.tiktok,
    this.snapchat,
    this.facebook,
    this.website,
    this.latitude,
    this.longitude,
    this.minPrice,
    this.maxPrice,
    this.isFeatured = false,
    this.isVerified = false,
    this.isVip = false,
    this.isFollowing = false,
    this.followersCount = 0,
    this.isFavorite = false,
    this.activePlans = const <String>[],
    this.inSlider = false,
    this.isPremium = false,
    this.isActive = true,
    this.isStore = false,
    this.delegateName,
    this.ownerId,
    this.ownerName,
    this.ownerPhone,
    this.pointsBalance = 0,
    this.beneficiariesCount = 0,
    this.createdAt,
  });

  final int id;
  final String nameAr;
  final String nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? logo;
  final String? cover;
  final int? cityId;
  final int? categoryId;
  final CityModel? city;
  final CategoryModel? category;
  final double? rating;
  final int? reviewsCount;
  final int viewsCount;
  final String? phone;
  final String? address;
  final String? whatsapp;
  final String? instagram;
  final String? tiktok;
  final String? snapchat;
  final String? facebook;
  final String? website;
  final double? latitude;
  final double? longitude;
  final double? minPrice;
  final double? maxPrice;
  final bool isFeatured;
  final bool isVerified;
  final bool isFavorite;

  /// Active VIP subscription (drives slider visibility + verified badge).
  final bool isVip;

  /// Whether the current authenticated user follows this vendor.
  final bool isFollowing;

  /// Total number of users following this vendor.
  final int followersCount;

  /// Active subscription tier names returned by the API, e.g. `["slider","featured"]`.
  final List<String> activePlans;

  /// Vendor should appear in homepage sliders (slider OR featured plan active).
  final bool inSlider;

  /// Vendor has the featured/premium badge (manual flag or active featured plan).
  final bool isPremium;

  /// Whether the shop is active/visible. Admins can toggle this.
  final bool isActive;

  /// Whether this vendor is a store (products + cart + orders enabled).
  final bool isStore;

  /// Name of the delegate responsible for this shop's owner account.
  /// Only populated for admin requests (`/vendors` eager-loads it).
  final String? delegateName;

  /// Owner (advertiser) account details — only populated for admin requests.
  /// The phone doubles as the login username. Lets an admin reset the
  /// advertiser's password directly from the shop-edit screen.
  final int? ownerId;
  final String? ownerName;
  final String? ownerPhone;

  /// Points transferred to this vendor by users redeeming rewards.
  /// 1000 points = one subscription month.
  final int pointsBalance;

  /// Permanent count of users who redeemed points at this vendor
  /// (does not reset when an admin zeroes the points balance).
  final int beneficiariesCount;

  /// When the shop joined — drives the home "انضم مؤخراً" row.
  final DateTime? createdAt;

  String get name => nameAr.isNotEmpty ? nameAr : nameEn;
  String get description =>
      (descriptionAr?.isNotEmpty ?? false) ? descriptionAr! : (descriptionEn ?? '');

  /// Highest active subscription tier (vip > featured > normal), or null.
  String? get activePlan {
    if (isVip || activePlans.contains('vip')) return 'vip';
    if (activePlans.contains('featured')) return 'featured';
    if (activePlans.contains('normal')) return 'normal';
    return null;
  }

  /// Arabic label of the current subscription for display to the vendor.
  String get subscriptionLabel {
    switch (activePlan) {
      case 'vip':
        return 'VIP';
      case 'featured':
        return 'مميز';
      case 'normal':
        return 'عادي';
      default:
        return 'لا يوجد اشتراك فعّال';
    }
  }

  factory VendorModel.fromJson(Map<String, dynamic> json) => VendorModel(
        id: _toInt(json['id']) ?? 0,
        nameAr: (json['name_ar'] ?? json['name'] ?? '').toString(),
        nameEn: (json['name_en'] ?? '').toString(),
        descriptionAr: _readT<String>(json, 'description_ar'),
        descriptionEn: _readT<String>(json, 'description_en'),
        logo: _readT<String>(json, 'logo'),
        cover: _readT<String>(json, 'cover_image') ?? _readT<String>(json, 'cover'),
        cityId: _toInt(json['city_id']),
        categoryId: _toInt(json['category_id']),
        city: json['city'] is Map
            ? CityModel.fromJson(Map<String, dynamic>.from(json['city'] as Map))
            : null,
        category: json['category'] is Map
            ? CategoryModel.fromJson(
                Map<String, dynamic>.from(json['category'] as Map))
            : null,
        rating: _toDouble(json['rating']),
        reviewsCount: _toInt(json['reviews_count']),
        viewsCount: _toInt(json['views_count']) ?? 0,
        phone: _readT<String>(json, 'phone'),
        address: _readT<String>(json, 'address'),
        whatsapp: _readT<String>(json, 'whatsapp'),
        instagram: _readT<String>(json, 'instagram'),
        tiktok: _readT<String>(json, 'tiktok'),
        snapchat: _readT<String>(json, 'snapchat'),
        facebook: _readT<String>(json, 'facebook'),
        website: _readT<String>(json, 'website'),
        latitude: _toDouble(json['latitude']),
        longitude: _toDouble(json['longitude']),
        minPrice: _toDouble(json['min_price']),
        maxPrice: _toDouble(json['max_price']),
        isFeatured: json['is_featured'] == true || json['is_featured'] == 1,
        isVip: json['is_vip'] == true || json['is_vip'] == 1,
        // VIP subscription also grants the verified badge.
        isVerified: json['is_verified'] == true ||
            json['is_verified'] == 1 ||
            json['is_vip'] == true ||
            json['is_vip'] == 1,
        isFavorite: json['is_favorite'] == true,
        isFollowing: json['is_following'] == true || json['is_following'] == 1,
        followersCount: _toInt(json['followers_count']) ?? 0,
        activePlans: (json['active_plans'] is List)
            ? List<String>.from(
                (json['active_plans'] as List).map((e) => e.toString()))
            : const <String>[],
        inSlider: json['in_slider'] == true || json['in_slider'] == 1,
        isPremium: json['is_premium'] == true || json['is_premium'] == 1,
        isActive: json['is_active'] == null
            ? true
            : (json['is_active'] == true || json['is_active'] == 1),
        isStore: json['is_store'] == true || json['is_store'] == 1,
        delegateName: json['user'] is Map &&
                (json['user'] as Map)['delegate'] is Map
            ? _readT<String>(
                Map<String, dynamic>.from(
                    (json['user'] as Map)['delegate'] as Map),
                'name')
            : null,
        ownerId: json['user'] is Map
            ? _toInt((json['user'] as Map)['id'])
            : _toInt(json['user_id']),
        ownerName: json['user'] is Map
            ? _readT<String>(
                Map<String, dynamic>.from(json['user'] as Map), 'name')
            : null,
        ownerPhone: json['user'] is Map
            ? _readT<String>(
                Map<String, dynamic>.from(json['user'] as Map), 'phone')
            : null,
        pointsBalance: _toInt(json['points_balance']) ?? 0,
        beneficiariesCount: _toInt(json['beneficiaries_count']) ?? 0,
        createdAt: _toDate(json['created_at']),
      );
}

// ---------------------------------------------------------------------------
// SERVICE
// ---------------------------------------------------------------------------

class ServiceModel {
  ServiceModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    this.price,
    this.discountPrice,
    this.image,
    this.vendorId,
    this.vendor,
  });

  final int id;
  final String titleAr;
  final String titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final double? price;
  final double? discountPrice;
  final String? image;
  final int? vendorId;
  final VendorModel? vendor;

  String get title => titleAr.isNotEmpty ? titleAr : titleEn;
  String get description =>
      (descriptionAr?.isNotEmpty ?? false) ? descriptionAr! : (descriptionEn ?? '');

  /// True when a valid discount (less than the base price) is set.
  bool get hasDiscount =>
      discountPrice != null &&
      price != null &&
      discountPrice! > 0 &&
      discountPrice! < price!;

  /// The price the customer actually pays (discounted when applicable).
  double? get effectivePrice => hasDiscount ? discountPrice : price;

  /// Discount percentage off the base price, e.g. 25 for 25% off.
  int get discountPercent =>
      hasDiscount ? (((price! - discountPrice!) / price!) * 100).round() : 0;

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: _toInt(json['id']) ?? 0,
        titleAr: (json['title_ar'] ?? json['name_ar'] ?? json['title'] ?? '')
            .toString(),
        titleEn: (json['title_en'] ?? json['name_en'] ?? '').toString(),
        descriptionAr: _readT<String>(json, 'description_ar'),
        descriptionEn: _readT<String>(json, 'description_en'),
        price: _toDouble(json['price']),
        discountPrice: _toDouble(json['discount_price']),
        image: _readT<String>(json, 'image'),
        vendorId: _toInt(json['vendor_id']),
        vendor: json['vendor'] is Map
            ? VendorModel.fromJson(
                Map<String, dynamic>.from(json['vendor'] as Map))
            : null,
      );
}

// ---------------------------------------------------------------------------
// BOOKING
// ---------------------------------------------------------------------------

class BookingModel {
  BookingModel({
    required this.id,
    required this.eventDate,
    this.reference,
    this.status,
    this.notes,
    this.cancellationReason,
    this.totalPrice,
    this.serviceId,
    this.vendorId,
    this.service,
    this.vendor,
    this.customer,
    this.eventTime,
    this.guestsCount,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final DateTime eventDate;

  /// Human-readable booking number, e.g. `BK-6A3F…`.
  final String? reference;

  final String? status;
  final String? notes;

  /// The shop's own words when it rejects or cancels — the closest thing to a
  /// reply the customer gets, so it must never be swallowed.
  final String? cancellationReason;

  final double? totalPrice;
  final int? serviceId;
  final int? vendorId;
  final ServiceModel? service;
  final VendorModel? vendor;

  final DateTime? createdAt;

  /// When the shop last touched the booking — used to date its reply.
  final DateTime? updatedAt;

  /// True once the shop has acted on the request (anything but `pending`).
  bool get hasVendorReply => status != null && status != 'pending';

  /// The customer who made the booking. Present when a vendor/admin views their
  /// bookings (the API eager-loads the user). Null for a customer's own list.
  final UserModel? customer;
  final String? eventTime;
  final int? guestsCount;

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: _toInt(json['id']) ?? 0,
        eventDate:
            _toDate(json['event_date']) ?? _toDate(json['date']) ?? DateTime.now(),
        reference: _readT<String>(json, 'reference'),
        status: _readT<String>(json, 'status'),
        notes: _readT<String>(json, 'notes'),
        cancellationReason: _readT<String>(json, 'cancellation_reason'),
        totalPrice: _toDouble(json['total_price']),
        serviceId: _toInt(json['service_id']),
        vendorId: _toInt(json['vendor_id']),
        service: json['service'] is Map
            ? ServiceModel.fromJson(
                Map<String, dynamic>.from(json['service'] as Map))
            : null,
        vendor: json['vendor'] is Map
            ? VendorModel.fromJson(
                Map<String, dynamic>.from(json['vendor'] as Map))
            : null,
        customer: json['user'] is Map
            ? UserModel.fromJson(
                Map<String, dynamic>.from(json['user'] as Map))
            : null,
        eventTime: _readT<String>(json, 'event_time'),
        guestsCount: _toInt(json['guests_count']),
        createdAt: _toDate(json['created_at']),
        updatedAt: _toDate(json['updated_at']),
      );
}

// ---------------------------------------------------------------------------
// REVIEW
// ---------------------------------------------------------------------------

class ReviewModel {
  ReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    this.user,
    this.guestName,
    this.vendorId,
    this.createdAt,
  });

  final int id;
  final double rating;
  final String? comment;
  final UserModel? user;

  /// Alias for admin-created ("fake") reviews that have no real user account.
  final String? guestName;
  final int? vendorId;
  final DateTime? createdAt;

  /// Reviewer name to display: the real user's name, else the alias.
  String get displayName =>
      (user?.name.isNotEmpty ?? false) ? user!.name : (guestName ?? 'مستخدم');

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id: _toInt(json['id']) ?? 0,
        rating: _toDouble(json['rating']) ?? 0,
        comment: _readT<String>(json, 'comment'),
        user: json['user'] is Map
            ? UserModel.fromJson(
                Map<String, dynamic>.from(json['user'] as Map))
            : null,
        guestName: _readT<String>(json, 'guest_name'),
        vendorId: _toInt(json['vendor_id']),
        createdAt: _toDate(json['created_at']),
      );
}

// ---------------------------------------------------------------------------
// PROMOTION
// ---------------------------------------------------------------------------

class PromotionModel {
  PromotionModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    this.image,
    this.images = const [],
    this.discountPercent,
    this.discountType,
    this.discountValue,
    this.startsAt,
    this.endsAt,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.vendorId,
    this.vendor,
  });

  final int id;
  final String titleAr;
  final String titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? image;
  /// Gallery of full-quality images (cover first). Falls back to [image].
  final List<String> images;
  final double? discountPercent;
  // Server-aligned discount fields: type = 'percent' | 'fixed'.
  final String? discountType;
  final double? discountValue;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final int? vendorId;
  final VendorModel? vendor;

  String get title => titleAr.isNotEmpty ? titleAr : titleEn;
  String get description =>
      (descriptionAr?.isNotEmpty ?? false) ? descriptionAr! : (descriptionEn ?? '');

  /// All displayable images: the gallery if present, otherwise the cover.
  List<String> get gallery {
    if (images.isNotEmpty) return images;
    final c = image;
    return (c != null && c.isNotEmpty) ? [c] : const [];
  }

  /// Human label for the discount, e.g. "25%" or "50 ₪".
  String get discountLabel {
    final v = discountValue ?? discountPercent;
    if (v == null || v <= 0) return '';
    final n = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return discountType == 'fixed' ? '$n ₪' : '$n%';
  }

  factory PromotionModel.fromJson(Map<String, dynamic> json) => PromotionModel(
        id: _toInt(json['id']) ?? 0,
        titleAr: (json['title_ar'] ?? json['title'] ?? '').toString(),
        titleEn: (json['title_en'] ?? '').toString(),
        descriptionAr: _readT<String>(json, 'description_ar'),
        descriptionEn: _readT<String>(json, 'description_en'),
        image: _readT<String>(json, 'image'),
        images: _toStringList(json['images']),
        discountPercent: _toDouble(json['discount_percent']),
        discountType: _readT<String>(json, 'discount_type'),
        discountValue: _toDouble(json['discount_value']),
        startsAt: _toDate(json['starts_at']),
        endsAt: _toDate(json['ends_at']),
        startDate: _toDate(json['start_date']),
        endDate: _toDate(json['end_date']),
        isActive: json['is_active'] == null
            ? true
            : (json['is_active'] == true || json['is_active'] == 1),
        vendorId: _toInt(json['vendor_id']),
        vendor: json['vendor'] is Map
            ? VendorModel.fromJson(
                Map<String, dynamic>.from(json['vendor'] as Map))
            : null,
      );
}

// ---------------------------------------------------------------------------
// STORY
// ---------------------------------------------------------------------------

class StoryModel {
  StoryModel({
    required this.id,
    required this.image,
    this.captionAr,
    this.captionEn,
    this.vendorId,
    this.vendor,
    this.createdAt,
    this.expiresAt,
    this.isApproved = true,
    this.viewsCount = 0,
  });

  final int id;
  final String image;
  final String? captionAr;
  final String? captionEn;
  final int? vendorId;
  final VendorModel? vendor;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final int viewsCount;

  /// Whether an admin has approved this story. Vendor-submitted stories start
  /// pending and only appear publicly once approved. Defaults to true for
  /// responses that don't include the flag (older servers).
  final bool isApproved;

  String get caption =>
      (captionAr?.isNotEmpty ?? false) ? captionAr! : (captionEn ?? '');

  factory StoryModel.fromJson(Map<String, dynamic> json) => StoryModel(
        id: _toInt(json['id']) ?? 0,
        image: (json['image'] ?? '').toString(),
        captionAr: _readT<String>(json, 'caption_ar'),
        captionEn: _readT<String>(json, 'caption_en'),
        vendorId: _toInt(json['vendor_id']),
        vendor: json['vendor'] is Map
            ? VendorModel.fromJson(
                Map<String, dynamic>.from(json['vendor'] as Map))
            : null,
        createdAt: _toDate(json['created_at']),
        expiresAt: _toDate(json['expires_at']),
        isApproved: json['is_approved'] == null
            ? true
            : (json['is_approved'] == true || json['is_approved'] == 1),
        viewsCount: _toInt(json['views_count']) ?? 0,
      );
}

class VendorStoriesGroup {
  VendorStoriesGroup({required this.vendor, required this.stories});
  final VendorModel vendor;
  final List<StoryModel> stories;

  factory VendorStoriesGroup.fromJson(Map<String, dynamic> json) {
    final v = Map<String, dynamic>.from(json['vendor'] as Map);
    final list = (json['stories'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => StoryModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return VendorStoriesGroup(
      vendor: VendorModel.fromJson(v),
      stories: list,
    );
  }
}

// ---------------------------------------------------------------------------
// HIGHLIGHTS (دائمة، مثل انستجرام)
// ---------------------------------------------------------------------------

class HighlightItemModel {
  HighlightItemModel({
    required this.id,
    required this.highlightId,
    required this.type,
    required this.mediaUrl,
    this.caption,
    this.sortOrder = 0,
  });

  final int id;
  final int highlightId;
  final String type; // 'image' | 'video'
  final String mediaUrl;
  final String? caption;
  final int sortOrder;

  bool get isVideo => type == 'video';

  factory HighlightItemModel.fromJson(Map<String, dynamic> json) =>
      HighlightItemModel(
        id: _toInt(json['id']) ?? 0,
        highlightId: _toInt(json['highlight_id']) ?? 0,
        type: (json['type'] ?? 'image').toString(),
        mediaUrl: (json['media_url'] ?? '').toString(),
        caption: _readT<String>(json, 'caption'),
        sortOrder: _toInt(json['sort_order']) ?? 0,
      );
}

class HighlightModel {
  HighlightModel({
    required this.id,
    required this.title,
    this.coverImage,
    this.vendorId,
    this.sortOrder = 0,
    this.isActive = true,
    this.items = const [],
  });

  final int id;
  final String title;
  final String? coverImage;
  final int? vendorId;
  final int sortOrder;
  final bool isActive;
  final List<HighlightItemModel> items;

  /// Cover falls back to the first item's media so a highlight always has a face.
  String? get cover => (coverImage?.isNotEmpty ?? false)
      ? coverImage
      : (items.isNotEmpty ? items.first.mediaUrl : null);

  factory HighlightModel.fromJson(Map<String, dynamic> json) => HighlightModel(
        id: _toInt(json['id']) ?? 0,
        title: (json['title'] ?? '').toString(),
        coverImage: _readT<String>(json, 'cover_image'),
        vendorId: _toInt(json['vendor_id']),
        sortOrder: _toInt(json['sort_order']) ?? 0,
        isActive: json['is_active'] == true || json['is_active'] == 1,
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map((m) =>
                HighlightItemModel.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// SLIDER (الإعلانات)
// ---------------------------------------------------------------------------

class SliderModel {
  const SliderModel({
    required this.id,
    required this.image,
    this.titleAr,
    this.titleEn,
    this.subtitleAr,
    this.subtitleEn,
    this.ctaAr,
    this.ctaEn,
    this.badgeAr,
    this.badgeEn,
    this.link,
    this.vendorId,
    this.sortOrder = 0,
  });

  final int id;
  final String image;
  final String? titleAr;
  final String? titleEn;
  final String? subtitleAr;
  final String? subtitleEn;
  final String? ctaAr;
  final String? ctaEn;
  final String? badgeAr;
  final String? badgeEn;
  final String? link;

  /// Optional advertiser this slide opens when tapped.
  final int? vendorId;
  final int sortOrder;

  String get title =>
      (titleAr?.isNotEmpty ?? false) ? titleAr! : (titleEn ?? '');
  String get subtitle =>
      (subtitleAr?.isNotEmpty ?? false) ? subtitleAr! : (subtitleEn ?? '');
  String get cta =>
      (ctaAr?.isNotEmpty ?? false) ? ctaAr! : (ctaEn ?? '');
  String get badge =>
      (badgeAr?.isNotEmpty ?? false) ? badgeAr! : (badgeEn ?? '');

  factory SliderModel.fromJson(Map<String, dynamic> json) => SliderModel(
        id: _toInt(json['id']) ?? 0,
        image: (json['image'] ?? '').toString(),
        titleAr: _readT<String>(json, 'title_ar'),
        titleEn: _readT<String>(json, 'title_en'),
        subtitleAr: _readT<String>(json, 'subtitle_ar'),
        subtitleEn: _readT<String>(json, 'subtitle_en'),
        ctaAr: _readT<String>(json, 'cta_ar'),
        ctaEn: _readT<String>(json, 'cta_en'),
        badgeAr: _readT<String>(json, 'badge_ar'),
        badgeEn: _readT<String>(json, 'badge_en'),
        link: _readT<String>(json, 'link'),
        vendorId: _toInt(json['vendor_id']),
        sortOrder: _toInt(json['sort_order']) ?? 0,
      );
}

// ---------------------------------------------------------------------------
// NOTIFICATION (الإشعارات)
// ---------------------------------------------------------------------------

class NotificationModel {
  const NotificationModel({
    required this.id,
    this.userId,
    this.titleAr,
    this.titleEn,
    this.bodyAr,
    this.bodyEn,
    this.type = 'info',
    this.image,
    this.link,
    this.readAt,
    this.createdAt,
  });

  final int id;
  final int? userId;
  final String? titleAr;
  final String? titleEn;
  final String? bodyAr;
  final String? bodyEn;
  final String type;
  final String? image;
  final String? link;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;
  bool get isBroadcast => userId == null;

  String get title =>
      (titleAr?.isNotEmpty ?? false) ? titleAr! : (titleEn ?? '');
  String get body =>
      (bodyAr?.isNotEmpty ?? false) ? bodyAr! : (bodyEn ?? '');

  NotificationModel copyWith({DateTime? readAt}) => NotificationModel(
        id: id,
        userId: userId,
        titleAr: titleAr,
        titleEn: titleEn,
        bodyAr: bodyAr,
        bodyEn: bodyEn,
        type: type,
        image: image,
        link: link,
        readAt: readAt ?? this.readAt,
        createdAt: createdAt,
      );

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    return NotificationModel(
      id: _toInt(json['id']) ?? 0,
      userId: _toInt(json['user_id']),
      titleAr: _readT<String>(json, 'title_ar'),
      titleEn: _readT<String>(json, 'title_en'),
      bodyAr: _readT<String>(json, 'body_ar'),
      bodyEn: _readT<String>(json, 'body_en'),
      type: (json['type'] ?? 'info').toString(),
      image: _readT<String>(json, 'image'),
      link: _readT<String>(json, 'link'),
      readAt: parseDate(json['read_at']),
      createdAt: parseDate(json['created_at']),
    );
  }
}


// ---------------------------------------------------------------------------
// SUBSCRIPTION
// ---------------------------------------------------------------------------

class SubscriptionModel {
  SubscriptionModel({
    required this.id,
    required this.userId,
    this.delegateId,
    this.cityId,
    required this.clientName,
    required this.clientPhone,
    this.workField,
    required this.planName,
    required this.amountPaid,
    this.totalAmount = 0,
    required this.commissionAmount,
    this.commissionPaid = false,
    this.paymentMethod,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.notes,
    this.client,
    this.delegate,
    this.payments = const [],
  });

  final int id;
  final int userId;
  final int? delegateId;
  final int? cityId;
  final String clientName;
  final String clientPhone;
  final String? workField;
  final String planName;
  final double amountPaid;
  final double totalAmount;
  final double commissionAmount;
  final bool commissionPaid;
  final String? paymentMethod;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // pending|active|expired|cancelled
  final String? notes;
  final UserModel? client;
  final UserModel? delegate;
  final List<SubscriptionPaymentModel> payments;

  /// Outstanding balance the client still owes.
  double get remaining {
    final r = totalAmount - amountPaid;
    return r > 0 ? r : 0;
  }

  bool get isFullyPaid => remaining <= 0;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) => SubscriptionModel(
        id: _toInt(json['id']) ?? 0,
        userId: _toInt(json['user_id']) ?? 0,
        delegateId: _toInt(json['delegate_id']),
        cityId: _toInt(json['city_id']),
        clientName: (json['client_name'] ?? '').toString(),
        clientPhone: (json['client_phone'] ?? '').toString(),
        workField: _readT<String>(json, 'work_field'),
        planName: (json['plan_name'] ?? 'standard').toString(),
        amountPaid: _toDouble(json['amount_paid']) ?? 0,
        totalAmount: _toDouble(json['total_amount']) ?? (_toDouble(json['amount_paid']) ?? 0),
        commissionAmount: _toDouble(json['commission_amount']) ?? 0,
        commissionPaid: json['commission_paid'] == true || json['commission_paid'] == 1,
        paymentMethod: _readT<String>(json, 'payment_method'),
        startDate: _toDate(json['start_date']) ?? DateTime.now(),
        endDate: _toDate(json['end_date']) ?? DateTime.now(),
        status: (json['status'] ?? 'active').toString(),
        notes: _readT<String>(json, 'notes'),
        client: json['client'] is Map
            ? UserModel.fromJson(Map<String, dynamic>.from(json['client'] as Map))
            : null,
        delegate: json['delegate'] is Map
            ? UserModel.fromJson(Map<String, dynamic>.from(json['delegate'] as Map))
            : null,
        payments: (json['payments'] as List? ?? const [])
            .whereType<Map>()
            .map((m) =>
                SubscriptionPaymentModel.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );

  bool get isActive => status == 'active';
}

class SubscriptionPaymentModel {
  SubscriptionPaymentModel({
    required this.id,
    required this.amount,
    this.method,
    this.notes,
    this.paidAt,
  });

  final int id;
  final double amount;
  final String? method;
  final String? notes;
  final DateTime? paidAt;

  factory SubscriptionPaymentModel.fromJson(Map<String, dynamic> json) =>
      SubscriptionPaymentModel(
        id: _toInt(json['id']) ?? 0,
        amount: _toDouble(json['amount']) ?? 0,
        method: _readT<String>(json, 'method'),
        notes: _readT<String>(json, 'notes'),
        paidAt: _toDate(json['paid_at']) ?? _toDate(json['created_at']),
      );
}

// ---------------------------------------------------------------------------
// POST (post / reel / course)
// ---------------------------------------------------------------------------

enum PostType { post, reel, course }

PostType postTypeFrom(String s) {
  switch (s) {
    case 'reel':   return PostType.reel;
    case 'course': return PostType.course;
    default:       return PostType.post;
  }
}

String postTypeTo(PostType t) {
  switch (t) {
    case PostType.reel:   return 'reel';
    case PostType.course: return 'course';
    case PostType.post:   return 'post';
  }
}

class PostModel {
  PostModel({
    required this.id,
    required this.vendorId,
    required this.userId,
    required this.type,
    this.title,
    this.body,
    this.mediaUrl,
    this.thumbnail,
    this.images = const [],
    this.price,
    this.duration,
    this.likesCount = 0,
    this.viewsCount = 0,
    this.commentsCount = 0,
    this.isPublished = true,
    this.isLiked = false,
    this.vendor,
    this.createdAt,
  });

  final int id;
  final int vendorId;
  final int userId;
  final PostType type;
  final String? title;
  final String? body;
  final String? mediaUrl;
  final String? thumbnail;
  final List<String> images;

  /// All displayable images for a post: the gallery if present, else the media.
  List<String> get gallery {
    if (images.isNotEmpty) return images;
    final m = mediaUrl;
    return (m != null && m.isNotEmpty) ? [m] : const [];
  }
  final double? price;
  final String? duration;
  final int likesCount;
  final int viewsCount;
  final int commentsCount;
  final bool isPublished;
  final bool isLiked;
  final VendorModel? vendor;
  final DateTime? createdAt;

  factory PostModel.fromJson(Map<String, dynamic> json) => PostModel(
        id: _toInt(json['id']) ?? 0,
        vendorId: _toInt(json['vendor_id']) ?? 0,
        userId: _toInt(json['user_id']) ?? 0,
        type: postTypeFrom((json['type'] ?? 'post').toString()),
        title: _readT<String>(json, 'title'),
        body: _readT<String>(json, 'body'),
        mediaUrl: _readT<String>(json, 'media_url'),
        thumbnail: _readT<String>(json, 'thumbnail'),
        images: _toStringList(json['images']),
        price: _toDouble(json['price']),
        duration: _readT<String>(json, 'duration'),
        likesCount: _toInt(json['likes_count']) ?? 0,
        viewsCount: _toInt(json['views_count']) ?? 0,
        commentsCount: _toInt(json['comments_count']) ?? 0,
        isPublished: json['is_published'] == true || json['is_published'] == 1,
        isLiked: json['is_liked'] == true || json['is_liked'] == 1,
        vendor: json['vendor'] is Map
            ? VendorModel.fromJson(Map<String, dynamic>.from(json['vendor'] as Map))
            : null,
        createdAt: _toDate(json['created_at']),
      );
}

// ---------------------------------------------------------------------------
// POST COMMENTS
// ---------------------------------------------------------------------------

class PostCommentModel {
  PostCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.isApproved,
    this.user,
    this.guestName,
    this.createdAt,
  });

  final int id;
  final int postId;
  final int userId;
  final String body;
  final bool isApproved;
  final UserModel? user;

  /// Alias for admin-created ("fake") comments that have no real user account.
  final String? guestName;
  final DateTime? createdAt;

  /// Commenter name to display: the real user's name, else the alias.
  String get displayName =>
      (user?.name.isNotEmpty ?? false) ? user!.name : (guestName ?? 'مستخدم');

  factory PostCommentModel.fromJson(Map<String, dynamic> json) => PostCommentModel(
        id: _toInt(json['id']) ?? 0,
        postId: _toInt(json['post_id']) ?? 0,
        userId: _toInt(json['user_id']) ?? 0,
        body: (json['body'] ?? '').toString(),
        isApproved: json['is_approved'] == true || json['is_approved'] == 1,
        user: json['user'] is Map
            ? UserModel.fromJson(Map<String, dynamic>.from(json['user'] as Map))
            : null,
        guestName: _readT<String>(json, 'guest_name'),
        createdAt: _toDate(json['created_at']),
      );
}

// ---------------------------------------------------------------------------
// DELEGATE COMMISSIONS SUMMARY
// ---------------------------------------------------------------------------

class CommissionsTotals {
  CommissionsTotals({
    required this.totalCollected,
    required this.totalCommission,
    required this.paidCommission,
    required this.unpaidCommission,
    required this.count,
  });

  final double totalCollected;
  final double totalCommission;
  final double paidCommission;
  final double unpaidCommission;
  final int count;

  factory CommissionsTotals.fromJson(Map<String, dynamic> json) => CommissionsTotals(
        totalCollected: _toDouble(json['total_collected']) ?? 0,
        totalCommission: _toDouble(json['total_commission']) ?? 0,
        paidCommission: _toDouble(json['paid_commission']) ?? 0,
        unpaidCommission: _toDouble(json['unpaid_commission']) ?? 0,
        count: _toInt(json['count']) ?? 0,
      );
}

// ---------------------------------------------------------------------------
// STORE PRODUCT
// ---------------------------------------------------------------------------

class ProductModel {
  ProductModel({
    required this.id,
    required this.vendorId,
    this.sectionId,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    this.image,
    this.images = const [],
    required this.price,
    this.discountPrice,
    this.isAvailable = true,
    this.sort = 0,
    this.vendorName,
    this.vendorLogo,
    this.vendorRating,
    this.vendorReviewsCount,
  });

  final int id;
  final int vendorId;
  final int? sectionId;
  final String nameAr;
  final String nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? image;
  final List<String> images;
  final double price;
  final double? discountPrice;
  final bool isAvailable;
  final int sort;

  /// Owning shop's name, eager-loaded by the API. Needed by the marketplace
  /// feed, where products from many shops sit side by side.
  final String? vendorName;

  /// Owning shop's logo and rating — a product has no rating of its own, so
  /// the marketplace card shows the shop's standing instead.
  final String? vendorLogo;
  final double? vendorRating;
  final int? vendorReviewsCount;

  String get name => nameAr.isNotEmpty ? nameAr : nameEn;
  String get description =>
      (descriptionAr?.isNotEmpty ?? false) ? descriptionAr! : (descriptionEn ?? '');

  /// The price a customer actually pays (discount when present).
  double get effectivePrice =>
      (discountPrice != null && discountPrice! > 0) ? discountPrice! : price;

  bool get hasDiscount => discountPrice != null && discountPrice! > 0 && discountPrice! < price;

  /// All displayable images: gallery if present, otherwise the cover.
  List<String> get gallery {
    if (images.isNotEmpty) return images;
    final c = image;
    return (c != null && c.isNotEmpty) ? [c] : const [];
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: _toInt(json['id']) ?? 0,
        vendorId: _toInt(json['vendor_id']) ?? 0,
        sectionId: _toInt(json['section_id']),
        nameAr: (json['name_ar'] ?? json['name'] ?? '').toString(),
        nameEn: (json['name_en'] ?? '').toString(),
        descriptionAr: _readT<String>(json, 'description_ar'),
        descriptionEn: _readT<String>(json, 'description_en'),
        image: _readT<String>(json, 'image'),
        images: _toStringList(json['images']),
        price: _toDouble(json['price']) ?? 0,
        discountPrice: _toDouble(json['discount_price']),
        isAvailable: json['is_available'] == null
            ? true
            : (json['is_available'] == true || json['is_available'] == 1),
        sort: _toInt(json['sort']) ?? 0,
        vendorName: json['vendor'] is Map
            ? (_readT<String>(
                    Map<String, dynamic>.from(json['vendor'] as Map), 'name_ar') ??
                _readT<String>(
                    Map<String, dynamic>.from(json['vendor'] as Map), 'name_en'))
            : null,
        vendorLogo: json['vendor'] is Map
            ? _readT<String>(
                Map<String, dynamic>.from(json['vendor'] as Map), 'logo')
            : null,
        vendorRating: json['vendor'] is Map
            ? _toDouble((json['vendor'] as Map)['rating'])
            : null,
        vendorReviewsCount: json['vendor'] is Map
            ? _toInt((json['vendor'] as Map)['reviews_count'])
            : null,
      );
}

// ---------------------------------------------------------------------------
// STORE PRODUCT SECTION (internal category inside a vendor)
// ---------------------------------------------------------------------------

class ProductSectionModel {
  ProductSectionModel({
    required this.id,
    required this.vendorId,
    required this.nameAr,
    this.nameEn,
    this.sort = 0,
    this.productsCount = 0,
  });

  final int id;
  final int vendorId;
  final String nameAr;
  final String? nameEn;
  final int sort;
  final int productsCount;

  String get name => nameAr.isNotEmpty ? nameAr : (nameEn ?? '');

  factory ProductSectionModel.fromJson(Map<String, dynamic> json) =>
      ProductSectionModel(
        id: _toInt(json['id']) ?? 0,
        vendorId: _toInt(json['vendor_id']) ?? 0,
        nameAr: (json['name_ar'] ?? '').toString(),
        nameEn: _readT<String>(json, 'name_en'),
        sort: _toInt(json['sort']) ?? 0,
        productsCount: _toInt(json['products_count']) ?? 0,
      );
}

// ---------------------------------------------------------------------------
// STORE ORDER (invoice)
// ---------------------------------------------------------------------------

class OrderItemModel {
  OrderItemModel({
    required this.productId,
    required this.name,
    this.image,
    required this.price,
    required this.quantity,
  });

  final int productId;
  final String name;
  final String? image;
  final double price;
  final int quantity;

  double get subtotal => price * quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        productId: _toInt(json['product_id']) ?? 0,
        name: (json['name'] ?? '').toString(),
        image: _readT<String>(json, 'image'),
        price: _toDouble(json['price']) ?? 0,
        quantity: _toInt(json['quantity']) ?? 1,
      );
}

class OrderModel {
  OrderModel({
    required this.id,
    required this.vendorId,
    this.vendorName,
    this.customerName,
    this.customerPhone,
    this.cityId,
    this.cityName,
    this.area,
    this.landmark,
    this.note,
    this.items = const [],
    required this.total,
    this.status = 'pending',
    this.createdAt,
  });

  final int id;
  final int vendorId;

  /// Owning shop's name, eager-loaded by the API — «طلباتي» lists orders from
  /// several shops side by side, so the id alone is useless there.
  final String? vendorName;

  final String? customerName;
  final String? customerPhone;

  /// Where the order is delivered: city, area (neighbourhood) and a nearby
  /// landmark. Collected at checkout — a shop can't deliver without them.
  final int? cityId;
  final String? cityName;
  final String? area;
  final String? landmark;

  final String? note;
  final List<OrderItemModel> items;
  final double total;
  final String status;
  final DateTime? createdAt;

  /// One-line address, e.g. «الخليل — وادي الهرية، بالقرب من مسجد الرحمة».
  String get addressLine {
    final parts = [
      if ((cityName ?? '').isNotEmpty) cityName!,
      if ((area ?? '').isNotEmpty) area!,
    ];
    var line = parts.join(' — ');
    if ((landmark ?? '').isNotEmpty) {
      line = line.isEmpty
          ? 'بالقرب من $landmark'
          : '$line، بالقرب من $landmark';
    }
    return line;
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: _toInt(json['id']) ?? 0,
        vendorId: _toInt(json['vendor_id']) ?? 0,
        vendorName: json['vendor'] is Map
            ? (_readT<String>(
                    Map<String, dynamic>.from(json['vendor'] as Map), 'name_ar') ??
                _readT<String>(
                    Map<String, dynamic>.from(json['vendor'] as Map), 'name_en'))
            : null,
        customerName: _readT<String>(json, 'customer_name'),
        customerPhone: _readT<String>(json, 'customer_phone'),
        cityId: _toInt(json['city_id']),
        cityName: json['city'] is Map
            ? _readT<String>(
                Map<String, dynamic>.from(json['city'] as Map), 'name_ar')
            : null,
        area: _readT<String>(json, 'area'),
        landmark: _readT<String>(json, 'landmark'),
        note: _readT<String>(json, 'note'),
        items: json['items'] is List
            ? (json['items'] as List)
                .whereType<Map>()
                .map((e) => OrderItemModel.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        total: _toDouble(json['total']) ?? 0,
        status: (json['status'] ?? 'pending').toString(),
        createdAt: _toDate(json['created_at']),
      );
}

// ---------------------------------------------------------------------------
// COMPETITION (توقّع النتيجة)
// ---------------------------------------------------------------------------

class CompetitionModel {
  CompetitionModel({
    required this.id,
    required this.title,
    this.description,
    this.sponsor,
    required this.teamAName,
    this.teamAFlag,
    required this.teamBName,
    this.teamBFlag,
    this.pageFacebook,
    this.pageInstagram,
    this.pageTiktok,
    this.resultWinner,
    this.resultScore,
    this.isActive = true,
  });

  final int id;
  final String title;
  final String? description;
  final VendorModel? sponsor;
  final String teamAName;
  final String? teamAFlag;
  final String teamBName;
  final String? teamBFlag;
  final String? pageFacebook;
  final String? pageInstagram;
  final String? pageTiktok;
  final String? resultWinner;
  final String? resultScore;
  final bool isActive;

  bool get hasResult => (resultWinner?.isNotEmpty ?? false);

  factory CompetitionModel.fromJson(Map<String, dynamic> json) =>
      CompetitionModel(
        id: _toInt(json['id']) ?? 0,
        title: (json['title'] ?? '').toString(),
        description: _readT<String>(json, 'description'),
        sponsor: json['sponsor'] is Map
            ? VendorModel.fromJson(
                Map<String, dynamic>.from(json['sponsor'] as Map))
            : null,
        teamAName: (json['team_a_name'] ?? '').toString(),
        teamAFlag: _readT<String>(json, 'team_a_flag'),
        teamBName: (json['team_b_name'] ?? '').toString(),
        teamBFlag: _readT<String>(json, 'team_b_flag'),
        pageFacebook: _readT<String>(json, 'page_facebook'),
        pageInstagram: _readT<String>(json, 'page_instagram'),
        pageTiktok: _readT<String>(json, 'page_tiktok'),
        resultWinner: _readT<String>(json, 'result_winner'),
        resultScore: _readT<String>(json, 'result_score'),
        isActive: json['is_active'] == true || json['is_active'] == 1,
      );
}

class PredictionModel {
  PredictionModel({
    required this.id,
    required this.competitionId,
    required this.winner,
    this.score,
  });

  final int id;
  final int competitionId;
  final String winner;
  final String? score;

  factory PredictionModel.fromJson(Map<String, dynamic> json) => PredictionModel(
        id: _toInt(json['id']) ?? 0,
        competitionId: _toInt(json['competition_id']) ?? 0,
        winner: (json['winner'] ?? '').toString(),
        score: _readT<String>(json, 'score'),
      );
}

// ---------------------------------------------------------------------------
// POINTS / REWARDS
// ---------------------------------------------------------------------------

/// A single "points spent at a vendor" record for the user's history.
class PointRedemptionModel {
  PointRedemptionModel({
    required this.id,
    required this.points,
    required this.vendorId,
    this.vendorName,
    this.vendorLogo,
    this.createdAt,
  });

  final int id;
  final int points;
  final int vendorId;
  final String? vendorName;
  final String? vendorLogo;
  final DateTime? createdAt;

  factory PointRedemptionModel.fromJson(Map<String, dynamic> json) {
    final v = json['vendor'] is Map
        ? Map<String, dynamic>.from(json['vendor'] as Map)
        : const <String, dynamic>{};
    return PointRedemptionModel(
      id: _toInt(json['id']) ?? 0,
      points: _toInt(json['points']) ?? 0,
      vendorId: _toInt(json['vendor_id']) ?? _toInt(v['id']) ?? 0,
      vendorName: (v['name_ar']?.toString().isNotEmpty ?? false)
          ? v['name_ar'].toString()
          : _readT<String>(v, 'name_en'),
      vendorLogo: _readT<String>(v, 'logo'),
      createdAt: _toDate(json['created_at']),
    );
  }
}

/// Full points summary shown on the rewards screen: balance, where the points
/// came from (breakdown), progress toward the next point in each category,
/// spend history, and the user's invite code.
/// One 50 ₪ cash-out the member has already taken.
class PointRewardModel {
  const PointRewardModel({
    required this.id,
    required this.points,
    required this.amountIls,
    required this.tier,
    required this.level,
    this.createdAt,
  });

  final int id;
  final int points;
  final int amountIls;
  final String tier;
  final int level;
  final DateTime? createdAt;

  factory PointRewardModel.fromJson(Map<String, dynamic> j) => PointRewardModel(
        id: _toInt(j['id']) ?? 0,
        points: _toInt(j['points']) ?? 0,
        amountIls: _toInt(j['amount_ils']) ?? 0,
        tier: (j['tier'] ?? '').toString(),
        level: _toInt(j['level']) ?? 1,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
      );
}

class PointsSummary {
  PointsSummary({
    required this.balance,
    required this.breakdown,
    required this.progress,
    required this.redemptions,
    this.referralCode,
    this.invitesCount = 0,
    this.threshold = 10,
    this.redeemCost = 50,
    this.redeemDiscount = 10,
    this.pointsPerShekel = 10,
    this.valueIls = 0,
    this.tier = 'برونزي',
    this.level = 1,
    this.goal = 100,
    this.rewardIls = 50,
    this.canClaim = false,
    this.rewardsTaken = 0,
    this.dailyCap = 3,
    this.dailyUsed = 0,
    this.streakDays = 0,
    this.streakNeeded = 30,
    this.streakAward = 90,
    this.invitePoints = 3,
    this.rewards = const [],
  });

  /// Where the member stands on the rewards ladder: the level's name, its
  /// number (levels keep counting past بلاتيني), and the points this level
  /// asks for before it pays [rewardIls].
  final String tier;
  final int level;
  final int goal;
  final int rewardIls;
  final bool canClaim;
  final int rewardsTaken;

  /// Interactions that still count today, out of the daily cap.
  final int dailyCap;
  final int dailyUsed;

  /// The run of consecutive days, what it must reach, and what it then pays.
  final int streakDays;
  final int streakNeeded;
  final int streakAward;

  /// Points a friend's registration is worth.
  final int invitePoints;

  /// Cash-outs already taken, newest first.
  final List<PointRewardModel> rewards;

  final int balance;

  /// How many points equal one shekel. Server-driven so the rate can be
  /// retuned from the dashboard without shipping a new build.
  final int pointsPerShekel;

  /// What [balance] is worth in shekels, as computed by the server.
  final double valueIls;

  /// category => points earned so far (e.g. {'signup':5,'reel_like':4}).
  final Map<String, int> breakdown;

  /// category => actions counted toward the next point (0..threshold-1).
  final Map<String, int> progress;

  final List<PointRedemptionModel> redemptions;
  final String? referralCode;
  final int invitesCount;
  final int threshold;
  final int redeemCost;
  final int redeemDiscount;

  static Map<String, int> _intMap(dynamic v) {
    final out = <String, int>{};
    if (v is Map) {
      v.forEach((k, val) {
        out[k.toString()] = _toInt(val) ?? 0;
      });
    }
    return out;
  }

  factory PointsSummary.fromJson(Map<String, dynamic> json) => PointsSummary(
        balance: _toInt(json['balance']) ?? 0,
        breakdown: _intMap(json['breakdown']),
        progress: _intMap(json['progress']),
        redemptions: (json['redemptions'] is List)
            ? (json['redemptions'] as List)
                .whereType<Map>()
                .map((e) =>
                    PointRedemptionModel.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        referralCode: _readT<String>(json, 'referral_code'),
        invitesCount: _toInt(json['invites_count']) ?? 0,
        threshold: _toInt(json['threshold']) ?? 10,
        tier: (json['tier'] ?? 'برونزي').toString(),
        level: _toInt(json['level']) ?? 1,
        goal: _toInt(json['goal']) ?? 100,
        rewardIls: _toInt(json['reward_ils']) ?? 50,
        canClaim: json['can_claim'] == true,
        rewardsTaken: _toInt(json['rewards_taken']) ?? 0,
        dailyCap: _toInt(json['daily_cap']) ?? 3,
        dailyUsed: _toInt(json['daily_used']) ?? 0,
        streakDays: _toInt(json['streak_days']) ?? 0,
        streakNeeded: _toInt(json['streak_needed']) ?? 30,
        streakAward: _toInt(json['streak_award']) ?? 90,
        invitePoints: _toInt(json['invite_points']) ?? 3,
        rewards: (json['rewards'] is List)
            ? (json['rewards'] as List)
                .whereType<Map>()
                .map((e) => PointRewardModel.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        redeemCost: _toInt(json['redeem_cost']) ?? 50,
        redeemDiscount: _toInt(json['redeem_discount']) ?? 10,
        pointsPerShekel: _toInt(json['points_per_shekel']) ?? 10,
        valueIls: _toDouble(json['value_ils']) ??
            ((_toInt(json['balance']) ?? 0) /
                ((_toInt(json['points_per_shekel']) ?? 10).clamp(1, 100000))),
      );

  /// Money value formatted for display, e.g. «2.5 ₪» / «12 ₪».
  String get valueLabel {
    final v = valueIls;
    final text = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    return '$text ₪';
  }

  /// Arabic label for each earning category, for the breakdown UI.
  static String categoryLabel(String key) {
    switch (key) {
      case 'signup':
        return 'إنشاء حساب';
      case 'invite':
        return 'دعوة أصدقاء';
      case 'subscription':
        return 'اشتراك سنوي';
      case 'streak':
        return 'نقاط الولاء اليومية';
      case 'story_comment':
        return 'تعليقات على الستوري';
      case 'service_comment':
        return 'تعليقات على الخدمات';
      case 'reel_like':
        return 'إعجابات على الريلز';
      case 'reel_comment':
        return 'تعليقات على الريلز';
      case 'post_like':
        return 'إعجابات على المنشورات';
      case 'post_comment':
        return 'تعليقات على المنشورات';
      case 'review':
        return 'تعليقات على الصفحات';
      case 'follow':
        return 'متابعة المحلات';
      default:
        return key;
    }
  }
}
