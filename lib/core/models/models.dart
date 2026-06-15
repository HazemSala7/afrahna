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
    this.isActive = true,
    this.delegateId,
    this.workField,
    this.cityId,
    this.commissionPerSubscription,
    this.permissions = const {},
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
      };

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
    this.isFavorite = false,
    this.activePlans = const <String>[],
    this.inSlider = false,
    this.isPremium = false,
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

  /// Active subscription tier names returned by the API, e.g. `["slider","featured"]`.
  final List<String> activePlans;

  /// Vendor should appear in homepage sliders (slider OR featured plan active).
  final bool inSlider;

  /// Vendor has the featured/premium badge (manual flag or active featured plan).
  final bool isPremium;

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
        isVerified: json['is_verified'] == true || json['is_verified'] == 1,
        isFavorite: json['is_favorite'] == true,
        activePlans: (json['active_plans'] is List)
            ? List<String>.from(
                (json['active_plans'] as List).map((e) => e.toString()))
            : const <String>[],
        inSlider: json['in_slider'] == true || json['in_slider'] == 1,
        isPremium: json['is_premium'] == true || json['is_premium'] == 1,
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
    required this.commissionAmount,
    this.commissionPaid = false,
    this.paymentMethod,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.notes,
    this.client,
    this.delegate,
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
  final double commissionAmount;
  final bool commissionPaid;
  final String? paymentMethod;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // pending|active|expired|cancelled
  final String? notes;
  final UserModel? client;
  final UserModel? delegate;

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
      );

  bool get isActive => status == 'active';
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
    this.price,
    this.duration,
    this.likesCount = 0,
    this.viewsCount = 0,
    this.commentsCount = 0,
    this.isPublished = true,
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
  final double? price;
  final String? duration;
  final int likesCount;
  final int viewsCount;
  final int commentsCount;
  final bool isPublished;
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
        price: _toDouble(json['price']),
        duration: _readT<String>(json, 'duration'),
        likesCount: _toInt(json['likes_count']) ?? 0,
        viewsCount: _toInt(json['views_count']) ?? 0,
        commentsCount: _toInt(json['comments_count']) ?? 0,
        isPublished: json['is_published'] == true || json['is_published'] == 1,
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
    this.createdAt,
  });

  final int id;
  final int postId;
  final int userId;
  final String body;
  final bool isApproved;
  final UserModel? user;
  final DateTime? createdAt;

  factory PostCommentModel.fromJson(Map<String, dynamic> json) => PostCommentModel(
        id: _toInt(json['id']) ?? 0,
        postId: _toInt(json['post_id']) ?? 0,
        userId: _toInt(json['user_id']) ?? 0,
        body: (json['body'] ?? '').toString(),
        isApproved: json['is_approved'] == true || json['is_approved'] == 1,
        user: json['user'] is Map
            ? UserModel.fromJson(Map<String, dynamic>.from(json['user'] as Map))
            : null,
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
