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
  });

  final int id;
  final String name;
  final String? previewImage;
  final String? backgroundImage;
  final String bgColor;
  final String textColor;
  final String accentColor;
  final String? fontFamily;

  factory InvitationTemplateModel.fromJson(Map<String, dynamic> j) => InvitationTemplateModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        previewImage: j['preview_image']?.toString(),
        backgroundImage: j['background_image']?.toString(),
        bgColor: (j['bg_color'] ?? '#FAF3EC').toString(),
        textColor: (j['text_color'] ?? '#3D2817').toString(),
        accentColor: (j['accent_color'] ?? '#B8835A').toString(),
        fontFamily: j['font_family']?.toString(),
      );
}

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
    return _asList(res.data).map(InvitationTemplateModel.fromJson).toList();
  }

  Future<List<InvitationModel>> list() async {
    final res = await _dio.get('/invitations');
    return _asList(res.data).map(InvitationModel.fromJson).toList();
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
}
