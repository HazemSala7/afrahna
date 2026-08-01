import 'package:flutter/material.dart';

/// A specialised, hand-picked icon for every vendor category — no generic
/// "three-shapes" placeholder. Shared by the home category row and the full
/// categories screen so both stay consistent. Order matters: more specific
/// matches come first.
IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  bool has(List<String> keys) => keys.any(n.contains);

  // Venues & halls
  if (has(['قاع', 'صال', 'قصر', 'منتجع', 'hall', 'venue'])) {
    return Icons.castle_rounded;
  }
  // Food & hospitality / catering
  if (has(['طعام', 'مطعم', 'ضياف', 'بوفيه', 'مأكولات', 'buffet', 'cater',
      'food'])) {
    return Icons.restaurant_rounded;
  }
  // Coffee / drinks
  if (has(['قهوة', 'كوفي', 'مشروب', 'باريستا', 'coffee', 'cafe'])) {
    return Icons.local_cafe_rounded;
  }
  // Sweets & cakes
  if (has(['حلوي', 'حلو', 'كيك', 'شوكولا', 'حلا', 'cake', 'sweet', 'dessert'])) {
    return Icons.cake_rounded;
  }
  // Fashion & dresses
  if (has(['أزياء', 'ازياء', 'موضة', 'فستان', 'فساتين', 'بدل', 'عبايات',
      'قماش', 'خياط', 'fashion', 'dress', 'suit'])) {
    return Icons.checkroom_rounded;
  }
  // Perfumes / fragrance
  if (has(['عطر', 'عطور', 'perfume', 'fragr', 'بخور', 'عود'])) {
    return Icons.spa_rounded;
  }
  // Accessories & jewellery
  if (has(['اكسسوار', 'إكسسوار', 'مجوهرات', 'مصاغ', 'ذهب', 'خاتم', 'خواتم',
      'jewel', 'accessor', 'ring'])) {
    return Icons.diamond_rounded;
  }
  // Beauty / makeup / salon / spa / hair
  if (has(['تجميل', 'مكياج', 'بيوتي', 'عناية', 'بشرة', 'سبا', 'شعر', 'كوافير',
      'صالون', 'makeup', 'beauty', 'salon', 'spa', 'hair'])) {
    return Icons.face_retouching_natural;
  }
  // Parties / events / organizing
  if (has(['حفل', 'مناسب', 'تنظيم', 'party', 'event', 'celebrat'])) {
    return Icons.celebration_rounded;
  }
  // Music / zaffe / DJ / bands
  if (has(['زف', 'زفة', 'موسيق', 'فرقة', 'طبل', 'اغاني', 'أغاني', 'dj',
      'music', 'band'])) {
    return Icons.music_note_rounded;
  }
  // Decor / kosha / equipment / lighting / rentals
  if (has(['كوش', 'ديكور', 'تجهيز', 'اضاء', 'إضاء', 'ليزر', 'تأجير', 'تزيين',
      'kosha', 'decor', 'equip', 'light', 'rental'])) {
    return Icons.chair_rounded;
  }
  // Photography & video
  if (has(['صور', 'تصوير', 'استوديو', 'كاميرا', 'فيديو', 'photo', 'video',
      'studio'])) {
    return Icons.photo_camera_rounded;
  }
  // Flowers & bouquets
  if (has(['ورد', 'زهور', 'بوكيه', 'باقة', 'flower', 'bouquet'])) {
    return Icons.local_florist_rounded;
  }
  // Cars & transport
  if (has(['سيار', 'ليموزين', 'باص', 'نقل', 'car', 'limo', 'transport'])) {
    return Icons.directions_car_filled_rounded;
  }
  // Hotels & stays
  if (has(['فندق', 'شقة', 'سكن', 'منام', 'hotel', 'resort', 'stay'])) {
    return Icons.hotel_rounded;
  }
  // Invitations & printing
  if (has(['دعو', 'بطاق', 'طباع', 'كرت', 'invit', 'card', 'print'])) {
    return Icons.mail_rounded;
  }
  // Gifts & favors
  if (has(['هدا', 'هدايا', 'توزيع', 'giveaway', 'gift', 'favor'])) {
    return Icons.card_giftcard_rounded;
  }
  // Engagement / rings
  if (has(['خطوبة', 'ملكة', 'engagement'])) {
    return Icons.favorite_rounded;
  }
  // Home & furniture
  if (has(['منزل', 'اثاث', 'أثاث', 'مفروش', 'ستائر', 'ستاير', 'مطبخ',
      'furniture', 'home', 'kitchen'])) {
    return Icons.weekend_rounded;
  }
  // Kids & children
  if (has(['اطفال', 'أطفال', 'مواليد', 'بيبي', 'kid', 'child', 'baby'])) {
    return Icons.child_friendly_rounded;
  }
  // Health / medical / clinics
  if (has(['صح', 'طبي', 'عياد', 'اسنان', 'أسنان', 'health', 'medic', 'clinic',
      'dental'])) {
    return Icons.medical_services_rounded;
  }
  // Extra / other / miscellaneous services
  if (has(['خدمات إضاف', 'خدمات اضاف', 'إضافي', 'اضافي', 'أخرى', 'اخرى',
      'متنوع', 'misc', 'other', 'extra', 'خدمات'])) {
    return Icons.miscellaneous_services_rounded;
  }

  // Varied fallback: unmapped categories still get DISTINCT icons (picked
  // deterministically from the name) instead of all sharing one placeholder.
  const fallback = <IconData>[
    Icons.auto_awesome_rounded,
    Icons.storefront_rounded,
    Icons.redeem_rounded,
    Icons.interests_rounded,
    Icons.workspace_premium_rounded,
    Icons.celebration_rounded,
    Icons.emoji_events_rounded,
    Icons.local_mall_rounded,
  ];
  return fallback[name.hashCode.abs() % fallback.length];
}
