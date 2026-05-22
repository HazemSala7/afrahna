// All data models for the Afrahna app.
// Bilingual fields (ar/en) map to the corresponding columns in the Laravel API.

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
  });

  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? role;
  final String? avatar;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: _toInt(json['id']) ?? 0,
        name: (json['name'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        email: _readT<String>(json, 'email'),
        role: _readT<String>(json, 'role'),
        avatar: _readT<String>(json, 'avatar'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role,
        'avatar': avatar,
      };

  bool get isVendor => role == 'vendor';
  bool get isAdmin => role == 'admin';
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
  });

  final int id;
  final String nameAr;
  final String nameEn;
  final String? icon;
  final String? slug;

  String get name => nameAr.isNotEmpty ? nameAr : nameEn;

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: _toInt(json['id']) ?? 0,
        nameAr: (json['name_ar'] ?? json['name'] ?? '').toString(),
        nameEn: (json['name_en'] ?? '').toString(),
        icon: _readT<String>(json, 'icon'),
        slug: _readT<String>(json, 'slug'),
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
    this.phone,
    this.address,
    this.minPrice,
    this.maxPrice,
    this.isFeatured = false,
    this.isVerified = false,
    this.isFavorite = false,
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
  final String? phone;
  final String? address;
  final double? minPrice;
  final double? maxPrice;
  final bool isFeatured;
  final bool isVerified;
  final bool isFavorite;

  String get name => nameAr.isNotEmpty ? nameAr : nameEn;
  String get description =>
      (descriptionAr?.isNotEmpty ?? false) ? descriptionAr! : (descriptionEn ?? '');

  factory VendorModel.fromJson(Map<String, dynamic> json) => VendorModel(
        id: _toInt(json['id']) ?? 0,
        nameAr: (json['name_ar'] ?? json['name'] ?? '').toString(),
        nameEn: (json['name_en'] ?? '').toString(),
        descriptionAr: _readT<String>(json, 'description_ar'),
        descriptionEn: _readT<String>(json, 'description_en'),
        logo: _readT<String>(json, 'logo'),
        cover: _readT<String>(json, 'cover'),
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
        phone: _readT<String>(json, 'phone'),
        address: _readT<String>(json, 'address'),
        minPrice: _toDouble(json['min_price']),
        maxPrice: _toDouble(json['max_price']),
        isFeatured: json['is_featured'] == true || json['is_featured'] == 1,
        isVerified: json['is_verified'] == true || json['is_verified'] == 1,
        isFavorite: json['is_favorite'] == true,
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
  final String? image;
  final int? vendorId;
  final VendorModel? vendor;

  String get title => titleAr.isNotEmpty ? titleAr : titleEn;
  String get description =>
      (descriptionAr?.isNotEmpty ?? false) ? descriptionAr! : (descriptionEn ?? '');

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: _toInt(json['id']) ?? 0,
        titleAr: (json['title_ar'] ?? json['name_ar'] ?? json['title'] ?? '')
            .toString(),
        titleEn: (json['title_en'] ?? json['name_en'] ?? '').toString(),
        descriptionAr: _readT<String>(json, 'description_ar'),
        descriptionEn: _readT<String>(json, 'description_en'),
        price: _toDouble(json['price']),
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
    this.status,
    this.notes,
    this.totalPrice,
    this.serviceId,
    this.vendorId,
    this.service,
    this.vendor,
  });

  final int id;
  final DateTime eventDate;
  final String? status;
  final String? notes;
  final double? totalPrice;
  final int? serviceId;
  final int? vendorId;
  final ServiceModel? service;
  final VendorModel? vendor;

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: _toInt(json['id']) ?? 0,
        eventDate:
            _toDate(json['event_date']) ?? _toDate(json['date']) ?? DateTime.now(),
        status: _readT<String>(json, 'status'),
        notes: _readT<String>(json, 'notes'),
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
    this.vendorId,
    this.createdAt,
  });

  final int id;
  final double rating;
  final String? comment;
  final UserModel? user;
  final int? vendorId;
  final DateTime? createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id: _toInt(json['id']) ?? 0,
        rating: _toDouble(json['rating']) ?? 0,
        comment: _readT<String>(json, 'comment'),
        user: json['user'] is Map
            ? UserModel.fromJson(
                Map<String, dynamic>.from(json['user'] as Map))
            : null,
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
    this.discountPercent,
    this.startsAt,
    this.endsAt,
    this.vendorId,
    this.vendor,
  });

  final int id;
  final String titleAr;
  final String titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? image;
  final double? discountPercent;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? vendorId;
  final VendorModel? vendor;

  String get title => titleAr.isNotEmpty ? titleAr : titleEn;
  String get description =>
      (descriptionAr?.isNotEmpty ?? false) ? descriptionAr! : (descriptionEn ?? '');

  factory PromotionModel.fromJson(Map<String, dynamic> json) => PromotionModel(
        id: _toInt(json['id']) ?? 0,
        titleAr: (json['title_ar'] ?? json['title'] ?? '').toString(),
        titleEn: (json['title_en'] ?? '').toString(),
        descriptionAr: _readT<String>(json, 'description_ar'),
        descriptionEn: _readT<String>(json, 'description_en'),
        image: _readT<String>(json, 'image'),
        discountPercent: _toDouble(json['discount_percent']),
        startsAt: _toDate(json['starts_at']),
        endsAt: _toDate(json['ends_at']),
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
  });

  final int id;
  final String image;
  final String? captionAr;
  final String? captionEn;
  final int? vendorId;
  final VendorModel? vendor;
  final DateTime? createdAt;
  final DateTime? expiresAt;

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
