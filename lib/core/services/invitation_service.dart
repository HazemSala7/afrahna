import 'package:dio/dio.dart';

import '../api/api_client.dart';

class InvitationTemplateModel {
  InvitationTemplateModel({
    required this.id,
    required this.name,
    this.previewImage,
    this.backgroundImage,
    this.bgColor = '#FAF3EC',
    this.textColor = '#3D2817',
    this.accentColor = '#B8835A',
    this.fontFamily,
    this.animation = 'none',
  });

  final int id;
  final String name;
  final String? previewImage;
  final String? backgroundImage;
  final String bgColor;
  final String textColor;
  final String accentColor;
  final String? fontFamily;

  /// Which living background this theme paints behind the card
  /// ('gold_dust' | 'petals' | 'bokeh' | 'star' | 'silk' | 'arabesque' |
  /// 'candles' | 'foil' | 'none'). Server-driven so new themes can ship
  /// without a new build once the backend serves them.
  final String animation;

  bool get isAnimated => animation != 'none' && animation.isNotEmpty;

  factory InvitationTemplateModel.fromJson(Map<String, dynamic> j) => InvitationTemplateModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        previewImage: j['preview_image']?.toString(),
        backgroundImage: j['background_image']?.toString(),
        bgColor: (j['bg_color'] ?? '#FAF3EC').toString(),
        textColor: (j['text_color'] ?? '#3D2817').toString(),
        accentColor: (j['accent_color'] ?? '#B8835A').toString(),
        fontFamily: j['font_family']?.toString(),
        animation: (j['animation'] ?? 'none').toString(),
      );
}

/// Animated themes bundled with the app (ids ≥9000 so they never collide with
/// backend rows). The editor sends a null `template_id` for these, so the
/// backend accepts the invitation until it serves its own animated set.
final List<InvitationTemplateModel> localAnimatedTemplates = [
  InvitationTemplateModel(
    id: 9001,
    name: 'غبار ذهبي',
    bgColor: '#1A1526',
    textColor: '#F3E9D2',
    accentColor: '#E6C36B',
    animation: 'gold_dust',
  ),
  InvitationTemplateModel(
    id: 9002,
    name: 'بتلات وردية',
    bgColor: '#FFF4F6',
    textColor: '#6B2740',
    accentColor: '#CE7D97',
    animation: 'petals',
  ),
  InvitationTemplateModel(
    id: 9003,
    name: 'أضواء بوكيه',
    bgColor: '#2A1830',
    textColor: '#F6E8F2',
    accentColor: '#E7B7D6',
    animation: 'bokeh',
  ),
  InvitationTemplateModel(
    id: 9004,
    name: 'سماء ماسية',
    bgColor: '#10203A',
    textColor: '#EDF2FB',
    accentColor: '#CFE0FF',
    animation: 'star',
  ),
  InvitationTemplateModel(
    id: 9005,
    name: 'حرير ملكي',
    bgColor: '#101A2E',
    textColor: '#F2E7CF',
    accentColor: '#D8B45F',
    animation: 'silk',
  ),
  InvitationTemplateModel(
    id: 9006,
    name: 'زخرفة عربية',
    bgColor: '#0F2020',
    textColor: '#EFE6D2',
    accentColor: '#C9A24D',
    animation: 'arabesque',
  ),
  InvitationTemplateModel(
    id: 9007,
    name: 'ضوء الشموع',
    bgColor: '#1E1410',
    textColor: '#F7E8D6',
    accentColor: '#F0B876',
    animation: 'candles',
  ),
  InvitationTemplateModel(
    id: 9008,
    name: 'وميض ذهبي',
    bgColor: '#141414',
    textColor: '#F5EFE3',
    accentColor: '#E8D9A0',
    animation: 'foil',
  ),
];

class InvitationModel {
  InvitationModel({
    required this.id,
    required this.code,
    required this.brideName,
    required this.groomName,
    required this.eventDate,
    this.venue,
    this.mapUrl,
    this.customMessage,
    this.templateId,
    this.template,
    this.viewsCount = 0,
    this.gallery = const [],
    this.giftNote,
    this.musicUrl,
    this.rsvpOpen = true,
  });

  final int id;
  final String code;
  final String brideName;
  final String groomName;
  final DateTime eventDate;
  final String? venue;
  final String? mapUrl;
  final String? customMessage;
  final int? templateId;
  final InvitationTemplateModel? template;
  final int viewsCount;

  /// Photos shown in the «لحظاتنا الجميلة» carousel.
  final List<String> gallery;

  /// Free text for «الهدايا والحصالة» — usually an IBAN or account number.
  final String? giftNote;

  final String? musicUrl;

  /// The couple can close attendance once the list is settled.
  final bool rsvpOpen;

  String get shareUrl => 'https://afrahna.co/i/$code';

  factory InvitationModel.fromJson(Map<String, dynamic> j) => InvitationModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        code: (j['code'] ?? '').toString(),
        brideName: (j['bride_name'] ?? '').toString(),
        groomName: (j['groom_name'] ?? '').toString(),
        eventDate: DateTime.tryParse(j['event_date']?.toString() ?? '') ?? DateTime.now(),
        venue: j['venue']?.toString(),
        mapUrl: j['map_url']?.toString(),
        customMessage: j['custom_message']?.toString(),
        templateId: (j['template_id'] as num?)?.toInt(),
        template: j['template'] is Map
            ? InvitationTemplateModel.fromJson(Map<String, dynamic>.from(j['template'] as Map))
            : null,
        viewsCount: (j['views_count'] as num?)?.toInt() ?? 0,
        gallery: j['gallery'] is List
            ? (j['gallery'] as List)
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList()
            : const [],
        giftNote: j['gift_note']?.toString(),
        musicUrl: j['music_url']?.toString(),
        rsvpOpen: j['rsvp_open'] == null
            ? true
            : (j['rsvp_open'] == true || j['rsvp_open'] == 1),
      );
}

/// This viewer's own reply, so the RSVP form opens pre-filled.
class MyRsvp {
  const MyRsvp({
    required this.name,
    required this.attending,
    required this.plusOnes,
    this.notes,
  });

  final String name;
  final bool attending;
  final int plusOnes;
  final String? notes;

  factory MyRsvp.fromJson(Map<String, dynamic> j) => MyRsvp(
        name: (j['name'] ?? '').toString(),
        attending: j['attending'] == true || j['attending'] == 1,
        plusOnes: (j['plus_ones'] as num?)?.toInt() ?? 0,
        notes: j['notes']?.toString(),
      );
}

/// A congratulation on the guestbook.
class InvitationWishModel {
  const InvitationWishModel({
    required this.id,
    required this.name,
    required this.body,
    this.createdAt,
  });

  final int id;
  final String name;
  final String body;
  final DateTime? createdAt;

  factory InvitationWishModel.fromJson(Map<String, dynamic> j) =>
      InvitationWishModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
      );
}

/// Everything the invitation screen renders in one payload.
class InvitationView {
  const InvitationView({
    required this.invitation,
    required this.confirmedCount,
    this.myRsvp,
    this.wishes = const [],
  });

  final InvitationModel invitation;

  /// Total people confirmed, counting each guest's +1s.
  final int confirmedCount;

  final MyRsvp? myRsvp;
  final List<InvitationWishModel> wishes;

  factory InvitationView.fromJson(Map<String, dynamic> j) => InvitationView(
        invitation: InvitationModel.fromJson(
          Map<String, dynamic>.from(j['invitation'] as Map),
        ),
        confirmedCount: (j['confirmed_count'] as num?)?.toInt() ?? 0,
        myRsvp: j['my_rsvp'] is Map
            ? MyRsvp.fromJson(Map<String, dynamic>.from(j['my_rsvp'] as Map))
            : null,
        wishes: j['wishes'] is List
            ? (j['wishes'] as List)
                .whereType<Map>()
                .map((e) =>
                    InvitationWishModel.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );
}

List<Map<String, dynamic>> _asList(dynamic body) {
  if (body is List) return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  if (body is Map && body['data'] is List) {
    return (body['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
}

Map<String, dynamic> _asMap(dynamic body) {
  if (body is Map) {
    if (body['data'] is Map) return Map<String, dynamic>.from(body['data'] as Map);
    return Map<String, dynamic>.from(body);
  }
  return const {};
}

class InvitationService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<InvitationTemplateModel>> templates() async {
    final res = await _dio.get('/invitation-templates');
    final remote =
        _asList(res.data).map(InvitationTemplateModel.fromJson).toList();
    // The animated themes live in the database now, so the server is the
    // source of truth. The bundled copies are only a fallback for an app
    // talking to a server that predates them — without a real row the chosen
    // theme can't be saved at all.
    final hasAnimated = remote.any((t) => t.isAnimated);
    return hasAnimated ? remote : [...remote, ...localAnimatedTemplates];
  }

  Future<List<InvitationModel>> list() async {
    final res = await _dio.get('/invitations');
    return _asList(res.data).map(InvitationModel.fromJson).toList();
  }

  /// One of the owner's own invitations, by id — how a notification about it
  /// (which carries the id) finds the share code the viewer screen needs.
  Future<InvitationModel> show(int id) async {
    final res = await _dio.get('/invitations/$id');
    return InvitationModel.fromJson(_asMap(res.data));
  }

  Future<InvitationModel> create({
    required String brideName,
    required String groomName,
    required DateTime eventDate,
    String? venue,
    String? mapUrl,
    String? customMessage,
    int? templateId,
  }) async {
    final res = await _dio.post('/invitations', data: {
      'bride_name': brideName,
      'groom_name': groomName,
      'event_date': eventDate.toUtc().toIso8601String(),
      if (venue != null && venue.isNotEmpty) 'venue': venue,
      if (mapUrl != null && mapUrl.isNotEmpty) 'map_url': mapUrl,
      if (customMessage != null && customMessage.isNotEmpty) 'custom_message': customMessage,
      'template_id': ?templateId,
    });
    return InvitationModel.fromJson(_asMap(res.data));
  }

  Future<InvitationModel> update(int id, Map<String, dynamic> patch) async {
    final body = <String, dynamic>{};
    patch.forEach((k, v) {
      if (v is DateTime) {
        body[k] = v.toUtc().toIso8601String();
      } else {
        body[k] = v;
      }
    });
    final res = await _dio.put('/invitations/$id', data: body);
    return InvitationModel.fromJson(_asMap(res.data));
  }

  Future<void> delete(int id) async {
    await _dio.delete('/invitations/$id');
  }

  // ---- Guest side: open an invitation you were sent, and reply ----

  /// Opens an invitation by its share code and counts a view.
  Future<InvitationView> viewByCode(String code) async {
    final res = await _dio.get('/invitations/code/$code');
    // Dio is configured to treat 4xx as a normal response, so an auth or
    // not-found error arrives here as a body without `invitation` and would
    // otherwise blow up as an opaque cast error in the model.
    final body = _asMap(res.data);
    if (body['invitation'] is! Map) {
      throw ApiException(
        (body['message'] ?? 'تعذّر فتح الدعوة (${res.statusCode})').toString(),
      );
    }
    return InvitationView.fromJson(body);
  }

  /// Submits or updates this viewer's attendance. Replying twice edits the
  /// same record, so the confirmed count never double-counts one person.
  Future<InvitationView> rsvp(
    String code, {
    required String name,
    required bool attending,
    int plusOnes = 0,
    String? phone,
    String? notes,
  }) async {
    final res = await _dio.post('/invitations/code/$code/rsvp', data: {
      'name': name,
      'attending': attending,
      'plus_ones': plusOnes,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return InvitationView.fromJson(_asMap(res.data));
  }

  /// Leaves a congratulation on the guestbook.
  Future<InvitationView> wish(
    String code, {
    required String name,
    required String body,
  }) async {
    final res = await _dio.post('/invitations/code/$code/wish', data: {
      'name': name,
      'body': body,
    });
    return InvitationView.fromJson(_asMap(res.data));
  }
}
