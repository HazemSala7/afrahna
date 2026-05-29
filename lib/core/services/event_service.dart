import 'package:dio/dio.dart';

import '../api/api_client.dart';

class EventModel {
  EventModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.startsAt,
    this.endsAt,
    this.location,
    this.color,
    this.icon,
    this.isMain = false,
    this.reminderMinutesBefore,
  });

  final int id;
  final int userId;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final String? color;
  final String? icon;
  final bool isMain;
  final int? reminderMinutesBefore;

  factory EventModel.fromJson(Map<String, dynamic> j) => EventModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '').toString(),
        description: j['description']?.toString(),
        startsAt: DateTime.tryParse(j['starts_at']?.toString() ?? '') ?? DateTime.now(),
        endsAt: j['ends_at'] != null ? DateTime.tryParse(j['ends_at'].toString()) : null,
        location: j['location']?.toString(),
        color: j['color']?.toString(),
        icon: j['icon']?.toString(),
        isMain: j['is_main'] == true || j['is_main'] == 1,
        reminderMinutesBefore: (j['reminder_minutes_before'] as num?)?.toInt(),
      );
}

List<Map<String, dynamic>> _asList(dynamic body) {
  if (body is List) return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  if (body is Map && body['data'] is List) {
    return (body['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
}

Map<String, dynamic>? _asMap(dynamic body) {
  if (body == null) return null;
  if (body is Map) {
    if (body['data'] is Map) return Map<String, dynamic>.from(body['data'] as Map);
    if (body.isEmpty) return null;
    return Map<String, dynamic>.from(body);
  }
  return null;
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

class EventService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<EventModel>> list({DateTime? from, DateTime? to, bool upcoming = false}) async {
    final res = await _dio.get('/events', queryParameters: {
      if (from != null) 'from': _iso(from),
      if (to != null) 'to': _iso(to),
      if (upcoming) 'upcoming': 1,
    });
    return _asList(res.data).map(EventModel.fromJson).toList();
  }

  Future<List<EventModel>> upcoming({int limit = 10}) async {
    final res = await _dio.get('/events/upcoming', queryParameters: {'limit': limit});
    return _asList(res.data).map(EventModel.fromJson).toList();
  }

  Future<EventModel?> main() async {
    final res = await _dio.get('/events/main');
    final m = _asMap(res.data);
    return m == null ? null : EventModel.fromJson(m);
  }

  Future<EventModel> create({
    required String title,
    String? description,
    required DateTime startsAt,
    DateTime? endsAt,
    String? location,
    bool isMain = false,
    int? reminderMinutesBefore,
  }) async {
    final res = await _dio.post('/events', data: {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'starts_at': _iso(startsAt),
      if (endsAt != null) 'ends_at': _iso(endsAt),
      if (location != null && location.isNotEmpty) 'location': location,
      'is_main': isMain,
      if (reminderMinutesBefore != null) 'reminder_minutes_before': reminderMinutesBefore,
    });
    return EventModel.fromJson(_asMap(res.data) ?? {});
  }

  Future<EventModel> update(int id, Map<String, dynamic> patch) async {
    final body = <String, dynamic>{};
    patch.forEach((k, v) {
      if (v is DateTime) {
        body[k] = _iso(v);
      } else {
        body[k] = v;
      }
    });
    final res = await _dio.put('/events/$id', data: body);
    return EventModel.fromJson(_asMap(res.data) ?? {});
  }

  Future<void> delete(int id) async {
    await _dio.delete('/events/$id');
  }
}
