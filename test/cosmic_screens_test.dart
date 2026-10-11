import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:afrahna/core/theme.dart';
import 'package:afrahna/features/auth/login_page.dart';
import 'package:afrahna/features/home/home_page.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:afrahna/core/models/models.dart';
import 'package:afrahna/features/account/account_page.dart';
import 'package:afrahna/features/assistant/assistant_page.dart';
import 'package:afrahna/features/categories/categories_page.dart';
import 'package:afrahna/features/coordinator/coordinator_page.dart';
import 'package:afrahna/features/event_request/event_request_page.dart';
import 'package:afrahna/features/favorites/favorites_page.dart';
import 'package:afrahna/features/invitations/invitations_page.dart';
import 'package:afrahna/features/offers/offer_details_page.dart';
import 'package:afrahna/features/store/my_orders_page.dart';
import 'package:afrahna/features/store/product_details_page.dart';
import 'package:afrahna/features/vendors/vendors_page.dart';
import 'package:afrahna/features/bookings/bookings_page.dart';
import 'package:afrahna/features/calendar/calendar_page.dart';
import 'package:afrahna/features/notifications/notifications_page.dart';
import 'package:afrahna/features/offers/offers_page.dart';
import 'package:afrahna/features/planning/planning_hub_page.dart';
import 'package:afrahna/features/store/cart_page.dart';
import 'package:afrahna/features/store/marketplace_page.dart';
import 'package:afrahna/features/tasks/tasks_page.dart';
import 'package:afrahna/features/vendors/vendor_details_page.dart';

import 'cosmic_harness.dart';

/// The screens past home, in the cosmic theme, for review by eye.
///
/// Refresh with `flutter test test/cosmic_screens_test.dart --update-goldens`.

final _user = UserModel(
  id: 1,
  name: 'حازم صالح',
  phone: '0599000000',
  role: 'customer',
  pointsBalance: 63,
  rewardsTaken: 1,
  referralCode: 'HZM4K9',
  createdAt: DateTime(2026, 7, 4),
);

/// A member whose session carries no share code yet: an account made from
/// the panel. The server mints one on `/auth/me`.
final _newcomer = UserModel(
  id: 1,
  name: 'حازم صالح',
  phone: '0599000000',
  role: 'customer',
  createdAt: DateTime(2026, 7, 4),
);

final _shopOwner = UserModel(
  id: 2,
  name: 'صاحب أزياء ميلانو',
  phone: '0599000002',
  role: 'vendor',
  pointsBalance: 7,
  createdAt: DateTime(2026, 5, 2),
);

/// [minutes] before now, as the API writes it.
String _ago(int minutes) => DateTime.now()
    .subtract(Duration(minutes: minutes))
    .toUtc()
    .toIso8601String();

Map<String, Object> _step(String status, String by, int minutesAgo,
        [String? note]) =>
    {
      'status': status,
      'by': by,
      'at': _ago(minutesAgo),
      'note': ?note,
    };

String _day(int fromToday, [int hour = 18]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + fromToday, hour)
      .toIso8601String();
}

final Map<String, Object> _vendorFull = {
  ...vendorJson(1, 'قاعة الأصالة', 'قاعات', 'الخليل', vip: true),
  'description_ar':
      'قاعة أفراح فاخرة تتسع لـ ٨٠٠ ضيف، بإضاءة ذكية وكوشة تُصمَّم لكل عروسين، '
          'وضيافة كاملة من المطبخ الخاص بالقاعة.',
  'phone': '0599123456',
  'whatsapp': '0599123456',
  'instagram': 'alasala.hall',
  'facebook': 'alasala.hall',
  'address': 'الخليل – شارع السلام',
  'min_price': 3500,
  'max_price': 12000,
  'followers_count': 1840,
  'views_count': 25300,
  'photos_count': 120,
  'videos_count': 26,
  'working_hours': 'يومياً 8:00 ص - 11:00 م',
  'delivery_note': 'توصيل داخل الخليل والمناطق المجاورة',
  'active_plans': ['vip'],
};

/// A post that carries pictures, for the shop page's photo row.
Map<String, Object> _photoPost(int id, int count) => {
      'id': id,
      'vendor_id': 1,
      'user_id': 1,
      'type': 'post',
      'title': 'من حفل الأسبوع',
      'images': [for (var i = 0; i < count; i++) 'https://x/p$id-$i.jpg'],
      'is_published': true,
      'created_at': _day(-id),
    };

final Map<String, Object> _bakery = {
  'id': 2,
  'name_ar': 'فتات الذهب',
  'name_en': 'Futat Al Dhahab',
  'category': {'id': 3, 'name_ar': 'معجنات'},
  'city': {'id': 8, 'name_ar': 'الخليل'},
  'rating': 0,
  'reviews_count': 0,
  'is_verified': false,
  'is_store': true,
  'phone': '0568125309',
  'whatsapp': '0568125309',
  'facebook': 'futat.aldhahab',
  'tiktok': 'futat.aldhahab',
  'address': 'الخليل',
  'followers_count': 7,
  'views_count': 1800,
  'photos_count': 0,
  'videos_count': 5,
};

/// The bakery again, with its bookings and reels switched off by an admin.
final Map<String, Object> _quietBakery = {
  ..._bakery,
  'id': 3,
  'allow_bookings': false,
  'allow_reels': false,
};

final Map<String, Object> _data = {
  '/auth/me': {
    'data': {
      'id': 1,
      'name': 'حازم صالح',
      'phone': '0599000000',
      'referral_code': 'HZM4K9',
    },
  },
  '/vendors/1': {'data': _vendorFull},
  '/vendors/2': {'data': _bakery},
  '/vendors/3': {'data': _quietBakery},
  '/services': {
    'data': [
      {
        'id': 1,
        'title_ar': 'باقة الذهب – ٥٠٠ ضيف',
        'description_ar': 'القاعة، الكوشة، الإضاءة، وضيافة الحلويات.',
        'price': 6500,
        'discount_price': 5800,
        'vendor_id': 1,
      },
      {
        'id': 2,
        'title_ar': 'باقة الألماس – ٨٠٠ ضيف',
        'description_ar': 'كل ما في الذهب، مع العشاء وفرقة الزفّة.',
        'price': 11000,
        'vendor_id': 1,
      },
    ],
  },
  '/vendors/1/reviews|/reviews': {
    'data': [
      {
        'id': 1,
        'rating': 5,
        'comment': 'تنظيم رائع وخدمة راقية من أول يوم لآخر لحظة.',
        'user': {'id': 7, 'name': 'رنا أبو شمسية', 'phone': '0599000007'},
        'created_at': _day(-3),
      },
      {
        'id': 2,
        'rating': 4,
        'comment': 'القاعة جميلة جداً والإضاءة ساحرة.',
        'guest_name': 'محمد المواسمي',
        'created_at': _day(-7),
      },
      {
        'id': 3,
        'rating': 5,
        'comment': 'أجمل كوشة شفتها، والضيافة فوق الممتازة.',
        'guest_name': 'سارة أحمد',
        'created_at': _day(-20),
      },
    ],
  },
  '/posts': {
    'data': [_photoPost(1, 3), _photoPost(2, 2)],
  },
  '/highlights': {
    'data': [
      for (final (i, t) in [
        'أصناف خاصة',
        'المناسبات',
        'الكوشة',
        'الإضاءة',
        'الضيافة',
        'آراء الزبائن',
      ].indexed)
        {
          'id': i + 1,
          'vendor_id': 1,
          'title': t,
          'cover_image': 'https://x/h$i.jpg',
          'is_active': true,
          'items': [
            {'id': i + 1, 'highlight_id': i + 1, 'type': 'image',
             'media_url': 'https://x/h$i.jpg'},
          ],
        },
    ],
  },
  '/promotions': {
    'data': [
      {
        'id': 1,
        'title_ar': 'خصم ٣٠٪ على جلسات التصوير الخارجية',
        'description_ar': 'لحجوزات شهر تشرين الأول فقط.',
        'discount_percent': 30,
        'is_active': true,
        'ends_at': _day(9),
        'vendor': vendorJson(2, 'استوديو لمسة', 'تصوير', 'نابلس'),
      },
      {
        'id': 2,
        'title_ar': 'باقة القاعة الذهبية مع ضيافة مجانية',
        'discount_percent': 15,
        'is_active': true,
        'ends_at': _day(20),
        'vendor': vendorJson(1, 'قاعة الأصالة', 'قاعات', 'الخليل'),
      },
      {
        'id': 3,
        'title_ar': 'مكياج العروس مع التسريحة بسعر خاص',
        'discount_percent': 20,
        'is_active': true,
        'ends_at': _day(4),
        'vendor': vendorJson(4, 'صالون هبة', 'تجميل وعناية', 'جنين'),
      },
    ],
  },
  '/products': {
    'data': [
      for (final (i, (name, price, disc)) in const [
        ('طقم ضيافة كريستال', 240.0, 199.0),
        ('صندوق شبكة مخملي', 95.0, null),
        ('فستان سهرة ساتان', 780.0, 650.0),
        ('باقة ورد جوري', 120.0, null),
        ('شموع معطّرة ×١٢', 60.0, 45.0),
        ('بطاقات دعوة مذهّبة ×١٠٠', 310.0, null),
      ].indexed)
        {
          'id': i + 1,
          'vendor_id': 3,
          'name_ar': name,
          'name_en': name,
          'price': price,
          'discount_price': disc,
          'vendor': {
            'id': 3,
            'name_ar': 'أزياء ميلانو',
            'rating': 4.8,
            'reviews_count': 92,
          },
        },
    ],
  },
  '/categories': {
    'data': [
      for (final (i, n) in const ['قاعات', 'تصوير', 'فساتين', 'زهور'].indexed)
        {'id': i + 1, 'name_ar': n, 'name_en': n, 'parent_id': null},
    ],
  },
  '/notifications': {
    'data': [
      {
        'id': 1,
        'title_ar': 'تم تأكيد حجزك 🎉',
        'body_ar': 'قاعة الأصالة أكّدت حجزك ليوم الخميس.',
        'type': 'booking',
        'created_at': _day(0, 9),
      },
      {
        'id': 2,
        'title_ar': 'عرض جديد من استوديو لمسة',
        'body_ar': 'خصم ٣٠٪ على جلسات التصوير الخارجية.',
        'type': 'promotion',
        'created_at': _day(-1, 13),
      },
      {
        'id': 3,
        'title_ar': 'ربحت ٣ نقاط',
        'body_ar': 'صديقك أنشأ حسابه بالكود الخاص بك.',
        'type': 'points',
        'read_at': _day(-2, 10),
        'created_at': _day(-2, 9),
      },
      {
        'id': 4,
        'title_ar': 'تذكير: موعد تجربة الفستان',
        'body_ar': 'غداً الساعة ٥ مساءً في أزياء ميلانو.',
        'type': 'reminder',
        'read_at': _day(-3, 10),
        'created_at': _day(-3, 8),
      },
    ],
  },
  '/notifications/unread-count': {'count': 2},
  '/bookings': {
    'data': [
      {
        'id': 1,
        'reference': 'AFR-20417',
        'event_date': _day(14),
        'event_time': '19:00',
        'status': 'confirmed',
        'user': {'id': 9, 'name': 'رنا خليل', 'phone': '0599111222'},
        'status_log': [
          _step('pending', 'customer', 60 * 26),
          _step('confirmed', 'vendor', 60 * 20),
        ],
        'total_price': 5800,
        'guests_count': 450,
        'service': {'id': 1, 'title_ar': 'باقة الذهب – ٥٠٠ ضيف'},
        'vendor': vendorJson(1, 'قاعة الأصالة', 'قاعات', 'الخليل'),
      },
      {
        'id': 2,
        'reference': 'AFR-20388',
        'event_date': _day(12),
        'status': 'pending',
        'user': {'id': 10, 'name': 'محمد عودة', 'phone': '0599333444'},
        'created_at': _ago(40),
        'status_log': [_step('pending', 'customer', 40)],
        'total_price': 1400,
        'service': {'id': 3, 'title_ar': 'جلسة تصوير خارجية'},
        'vendor': vendorJson(2, 'استوديو لمسة', 'تصوير', 'نابلس'),
      },
    ],
  },
  '/tasks/summary': {
    'total': 12,
    'pending': 6,
    'in_progress': 2,
    'done': 4,
    'overdue': 1,
  },
  '/tasks': {
    'data': [
      {
        'id': 1,
        'title': 'حجز القاعة',
        'status': 'done',
        'priority': 'high',
        'category': 'القاعة',
        'due_date': _day(-10),
        'completed_at': _day(-11),
      },
      {
        'id': 2,
        'title': 'اختيار المصوّر',
        'status': 'in_progress',
        'priority': 'high',
        'category': 'التصوير',
        'due_date': _day(3),
      },
      {
        'id': 3,
        'title': 'تجربة الفستان',
        'status': 'pending',
        'priority': 'medium',
        'category': 'العروس',
        'due_date': _day(1),
      },
      {
        'id': 4,
        'title': 'إرسال الدعوات',
        'status': 'pending',
        'priority': 'low',
        'category': 'الضيوف',
        'due_date': _day(-1),
      },
    ],
  },
  '/vendors/mine': {
    'data': {
      ...vendorJson(3, 'أزياء ميلانو', 'فساتين', 'رام الله', vip: true),
      'is_store': true,
      'followers_count': 920,
      'views_count': 14100,
      'user': {'id': 2, 'name': 'صاحب أزياء ميلانو'},
    },
  },
  '/orders': {
    'data': [
      {
        'id': 58,
        'vendor_id': 3,
        'vendor': {'id': 3, 'name_ar': 'أزياء ميلانو'},
        'customer_name': 'رنا خليل',
        'customer_phone': '0599111222',
        'city': {'id': 8, 'name_ar': 'رام الله'},
        'area': 'الماصيون',
        'landmark': 'مقابل مخبز الأصيل',
        'items': [
          {'product_id': 1, 'name': 'طقم ضيافة كريستال', 'price': 199, 'quantity': 2, 'subtotal': 398},
          {'product_id': 5, 'name': 'شموع معطّرة ×١٢', 'price': 45, 'quantity': 1, 'subtotal': 45},
        ],
        'total': 443,
        'status': 'preparing',
        'created_at': _ago(60 * 5),
        'status_log': [
          _step('pending', 'customer', 60 * 5),
          _step('confirmed', 'vendor', 60 * 4),
          _step('preparing', 'vendor', 35),
        ],
      },
      {
        'id': 57,
        'vendor_id': 3,
        'vendor': {'id': 3, 'name_ar': 'أزياء ميلانو'},
        'customer_name': 'محمد عودة',
        'customer_phone': '0599333444',
        'items': [
          {'product_id': 2, 'name': 'صندوق شبكة مخملي', 'price': 95, 'quantity': 1, 'subtotal': 95},
        ],
        'total': 95,
        'status': 'pending',
        'created_at': _ago(12),
        'status_log': [_step('pending', 'customer', 12)],
      },
      {
        'id': 51,
        'vendor_id': 3,
        'vendor': {'id': 3, 'name_ar': 'أزياء ميلانو'},
        'customer_name': 'سجى',
        'items': [
          {'product_id': 3, 'name': 'فستان سهرة ساتان', 'price': 650, 'quantity': 1, 'subtotal': 650},
        ],
        'total': 650,
        'status': 'rejected',
        'created_at': _ago(60 * 50),
        'status_log': [
          _step('pending', 'customer', 60 * 50),
          _step('rejected', 'vendor', 60 * 47, 'المقاس غير متوفر حالياً'),
        ],
      },
    ],
  },
  '/budget-items/summary': {
    'count': 6,
    'estimated': 48000,
    'actual': 31500,
    'paid': 22000,
    'remaining': 16500,
  },
  '/budget-items': {
    'data': [
      {'id': 1, 'name': 'القاعة', 'category': 'القاعة', 'estimated_amount': 12000, 'actual_amount': 11000, 'paid': true},
      {'id': 2, 'name': 'التصوير', 'category': 'التصوير', 'estimated_amount': 4000, 'actual_amount': 3500, 'paid': false},
      {'id': 3, 'name': 'فستان العروس', 'category': 'العروس', 'estimated_amount': 6000, 'actual_amount': 0, 'paid': false},
    ],
  },
  '/favorites': {
    'data': [
      vendorJson(1, 'قاعة الأصالة', 'قاعات', 'الخليل', vip: true),
      vendorJson(2, 'استوديو لمسة', 'تصوير', 'نابلس'),
      vendorJson(6, 'زهور فرح', 'زهور', 'بيت لحم'),
    ],
  },
  '/vendors': {
    'data': [
      vendorJson(1, 'قاعة الأصالة', 'قاعات', 'الخليل', vip: true),
      vendorJson(2, 'استوديو لمسة', 'تصوير', 'نابلس', vip: true),
      vendorJson(3, 'أزياء ميلانو', 'فساتين', 'رام الله'),
      vendorJson(4, 'صالون هبة', 'تجميل وعناية', 'جنين'),
      vendorJson(5, 'حلويات الشرق', 'ضيافة وحلويات', 'طولكرم'),
    ],
  },
  '/events/main': {
    'data': {
      'id': 1,
      'title': 'حفل الزفاف',
      'starts_at': _day(14, 19),
      'location': 'قاعة الأصالة',
      'is_main': true,
    },
  },
  '/events(/upcoming)?': {
    'data': [
      {
        'id': 1,
        'title': 'حفل الزفاف',
        'starts_at': _day(14, 19),
        'location': 'قاعة الأصالة',
        'is_main': true,
      },
      {
        'id': 2,
        'title': 'تجربة الفستان',
        'starts_at': _day(1, 17),
        'location': 'أزياء ميلانو',
      },
      {
        'id': 3,
        'title': 'جلسة التصوير',
        'starts_at': _day(5, 16),
        'color': '#7C6CF0',
      },
    ],
  },
};

void main() {
  cosmicSetUp();

  Future<void> screen(WidgetTester tester, Widget page, String name,
      {Size size = const Size(1080, 2340),
      bool signedIn = true,
      bool varies = false}) async {
    serve(_data);
    await shoot(
      tester,
      cosmicApp(page, session: signedIn ? SignedIn(_user) : null),
      name,
      size: size,
      varies: varies,
    );
  }

  testWidgets('account, signed in', (tester) async {
    await screen(tester, const AccountPage(), 'account',
        size: const Size(1080, 3400), varies: true);
  });

  testWidgets('account, guest', (tester) async {
    await screen(tester, const AccountPage(), 'account_guest',
        signedIn: false);
  });

  testWidgets('vendor profile', (tester) async {
    await screen(tester, const VendorDetailsPage(vendorId: 1), 'vendor',
        size: const Size(1080, 4200));
  });

  testWidgets('vendor profile, a bakery with a store and only reels',
      (tester) async {
    await screen(tester, const VendorDetailsPage(vendorId: 2), 'vendor_store',
        size: const Size(1080, 4200));
  });

  testWidgets('marketplace', (tester) async {
    await screen(tester, const MarketplacePage(), 'marketplace',
        size: const Size(1080, 3000));
  });

  testWidgets('offers', (tester) async {
    await screen(tester, const OffersPage(), 'offers', varies: true);
  });

  testWidgets('notifications', (tester) async {
    await screen(tester, const NotificationsPage(), 'notifications',
        varies: true);
  });

  testWidgets('planning hub', (tester) async {
    await screen(tester, const PlanningHubPage(), 'planning',
        size: const Size(1080, 3000));
  });

  testWidgets('tasks', (tester) async {
    await screen(tester, const TasksPage(), 'tasks', varies: true);
  });

  testWidgets('calendar', (tester) async {
    await screen(tester, const CalendarPage(), 'calendar',
        size: const Size(1080, 3000), varies: true);
  });

  testWidgets('bookings', (tester) async {
    await screen(tester, const BookingsPage(initialMine: true), 'bookings',
        varies: true);
  });

  testWidgets('categories', (tester) async {
    await screen(tester, const CategoriesPage(), 'categories');
  });

  testWidgets('vendors list', (tester) async {
    await screen(tester, const VendorsPage(title: 'قاعات'), 'vendors',
        size: const Size(1080, 3000));
  });

  testWidgets('product details', (tester) async {
    await screen(
      tester,
      ProductDetailsPage(
        product: ProductModel(
          id: 1,
          vendorId: 3,
          nameAr: 'طقم ضيافة كريستال',
          nameEn: 'Crystal set',
          descriptionAr: 'ستة فناجين وصينية مذهّبة، مغلّفة كهدية.',
          price: 240,
          discountPrice: 199,
          vendorName: 'أزياء ميلانو',
          vendorRating: 4.8,
          vendorReviewsCount: 92,
        ),
      ),
      'product',
    );
  });

  testWidgets('offer details', (tester) async {
    await screen(
      tester,
      OfferDetailsPage(
        promo: PromotionModel.fromJson({
          'id': 1,
          'title_ar': 'خصم ٣٠٪ على جلسات التصوير الخارجية',
          'description_ar': 'لحجوزات شهر تشرين الأول فقط، ويشمل ٥٠ صورة معدّلة.',
          'discount_percent': 30,
          'starts_at': _day(-3),
          'ends_at': _day(9),
          'vendor': vendorJson(2, 'استوديو لمسة', 'تصوير', 'نابلس'),
        }),
      ),
      'offer_details',
      varies: true,
    );
  });

  testWidgets('coordinator', (tester) async {
    await screen(tester, const CoordinatorPage(), 'coordinator');
  });

  testWidgets('assistant', (tester) async {
    await screen(tester, const AssistantPage(), 'assistant');
  });

  testWidgets('invitations', (tester) async {
    await screen(tester, const InvitationsPage(), 'invitations');
  });

  testWidgets('event request', (tester) async {
    await screen(tester, const EventRequestPage(), 'event_request',
        size: const Size(1080, 3000));
  });

  testWidgets('favorites', (tester) async {
    await screen(tester, const FavoritesPage(), 'favorites');
  });

  testWidgets('my orders, followed step by step', (tester) async {
    await screen(tester, const MyOrdersPage(), 'orders',
        size: const Size(1080, 4300), varies: true);
  });

  testWidgets('the shop answers its orders', (tester) async {
    serve(_data);
    await shoot(
      tester,
      cosmicApp(const MyOrdersPage(initialIncoming: true),
          session: SignedIn(_shopOwner)),
      'orders_shop',
      size: const Size(1080, 4600),
      varies: true,
    );
  });

  testWidgets('the shop answers its bookings', (tester) async {
    serve(_data);
    await shoot(
      tester,
      cosmicApp(const BookingsPage(), session: SignedIn(_shopOwner)),
      'bookings_shop',
      size: const Size(1080, 3200),
      varies: true,
    );
  });

  testWidgets('the shop account leads with what customers wait on',
      (tester) async {
    serve(_data);
    await shoot(
      tester,
      cosmicApp(const AccountPage(), session: SignedIn(_shopOwner)),
      'account_shop',
      size: const Size(1080, 2600),
    );
  });

  testWidgets('cart, empty', (tester) async {
    await screen(tester, const CartPage(), 'cart');
  });

  // The tab rail is a table of contents: a tap must move the page to the
  // section it names, and the rail must then mark that tab.
  testWidgets('a tab on the shop page scrolls to its section', (tester) async {
    serve(_data);
    // Tall enough that the rail is mid-screen and not under the floating
    // nav's home button, which would take the tap and leave the page.
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      cosmicApp(const VendorDetailsPage(vendorId: 2), session: SignedIn(_user)),
    );
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    final controller = scroll.controller!;
    expect(controller.offset, 0);

    // The stats strip repeats the tab labels, so aim at the tab itself: the
    // only InkWell carrying that text.
    Finder tab(String label) => find.widgetWithText(InkWell, label);
    expect(tab('الفيديوهات'), findsOneWidget);
    await tester.tap(tab('الفيديوهات'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    // ignore: avoid_print
    print('offset after tapping الفيديوهات: ${controller.offset}');
    expect(controller.offset, greaterThan(100));
    // and the rail marks the tab that was tapped
    final marked = tester.widget<Material>(
      find.ancestor(of: tab('الفيديوهات'), matching: find.byType(Material)).first,
    );
    expect(marked.color, AppColors.primaryDark);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 8));
  });

  // An admin switched this shop's bookings off: the page offers no booking,
  // and messaging takes the bright tone in its place.
  testWidgets('a shop with bookings switched off has no booking button',
      (tester) async {
    serve(_data);
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      cosmicApp(const VendorDetailsPage(vendorId: 3), session: SignedIn(_user)),
    );
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.text('احجز الآن'), findsNothing);
    expect(find.widgetWithText(InkWell, 'مراسلة'), findsOneWidget);
    // the verb and the tab both say it
    expect(find.widgetWithText(InkWell, 'المتجر'), findsAtLeastNWidgets(1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 8));
  });

  // A signed-in member whose session has no share code yet must never be
  // sent to sign in again: the code is fetched, then the sheet opens.
  testWidgets(
      'invite a friend fetches a missing code instead of asking to sign in',
      (tester) async {
    serve(_data);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      cosmicApp(const HomePage(), session: SignedIn(_newcomer)),
    );
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    await tester.tap(find.byIcon(Icons.card_giftcard_rounded).first);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.byType(LoginPage), findsNothing);
    expect(find.textContaining('afrahna.co/r/HZM4K9'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 8));
  });
}
