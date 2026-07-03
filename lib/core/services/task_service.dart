import 'package:dio/dio.dart';

import '../api/api_client.dart';

/// A wedding-planning task owned by the current user.
class TaskModel {
  TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.priority = 'medium',
    this.status = 'pending',
    this.category,
    this.sortOrder = 0,
    this.completedAt,
  });

  final int id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  /// low | medium | high
  final String priority;
  /// pending | in_progress | done
  final String status;
  final String? category;
  final int sortOrder;
  final DateTime? completedAt;

  bool get isDone => status == 'done';
  bool get isOverdue =>
      !isDone &&
      dueDate != null &&
      DateTime.now().isAfter(DateTime(dueDate!.year, dueDate!.month, dueDate!.day, 23, 59, 59));

  factory TaskModel.fromJson(Map<String, dynamic> j) => TaskModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '').toString(),
        description: j['description']?.toString(),
        dueDate: j['due_date'] != null
            ? DateTime.tryParse(j['due_date'].toString())
            : null,
        priority: (j['priority'] ?? 'medium').toString(),
        status: (j['status'] ?? 'pending').toString(),
        category: j['category']?.toString(),
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse(j['completed_at'].toString())
            : null,
      );
}

class TaskTemplateItem {
  TaskTemplateItem({
    required this.title,
    this.category,
    this.priority = 'medium',
    this.daysBefore,
  });
  final String title;
  final String? category;
  final String priority;
  final int? daysBefore;

  factory TaskTemplateItem.fromJson(Map<String, dynamic> j) => TaskTemplateItem(
        title: (j['title'] ?? '').toString(),
        category: j['category']?.toString(),
        priority: (j['priority'] ?? 'medium').toString(),
        daysBefore: (j['days_before'] as num?)?.toInt(),
      );
}

class TaskTemplateModel {
  TaskTemplateModel({
    required this.id,
    required this.titleAr,
    this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    this.icon,
    this.items = const [],
    this.isActive = true,
  });

  final int id;
  final String titleAr;
  final String? titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? icon;
  final List<TaskTemplateItem> items;
  final bool isActive;

  String get title => titleAr.isNotEmpty ? titleAr : (titleEn ?? '');

  factory TaskTemplateModel.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'];
    final items = (rawItems is List)
        ? rawItems
            .whereType<Map>()
            .map((m) => TaskTemplateItem.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <TaskTemplateItem>[];
    return TaskTemplateModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      titleAr: (j['title_ar'] ?? '').toString(),
      titleEn: j['title_en']?.toString(),
      descriptionAr: j['description_ar']?.toString(),
      descriptionEn: j['description_en']?.toString(),
      icon: j['icon']?.toString(),
      items: items,
      isActive: j['is_active'] == true || j['is_active'] == 1,
    );
  }
}

class TaskSummary {
  TaskSummary({
    this.total = 0,
    this.pending = 0,
    this.inProgress = 0,
    this.done = 0,
    this.overdue = 0,
  });
  final int total, pending, inProgress, done, overdue;

  double get progress => total == 0 ? 0 : done / total;

  factory TaskSummary.fromJson(Map<String, dynamic> j) => TaskSummary(
        total: (j['total'] as num?)?.toInt() ?? 0,
        pending: (j['pending'] as num?)?.toInt() ?? 0,
        inProgress: (j['in_progress'] as num?)?.toInt() ?? 0,
        done: (j['done'] as num?)?.toInt() ?? 0,
        overdue: (j['overdue'] as num?)?.toInt() ?? 0,
      );
}

List<Map<String, dynamic>> _asList(dynamic body) {
  if (body is List) {
    return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  if (body is Map && body['data'] is List) {
    return (body['data'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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

class TaskService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<TaskModel>> list({String? status}) async {
    try {
      final res = await _dio.get('/tasks', queryParameters: {
        'status': ?status,
      });
      return _asList(res.data).map(TaskModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<TaskSummary> summary() async {
    try {
      final res = await _dio.get('/tasks/summary');
      return TaskSummary.fromJson(_asMap(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<TaskModel> create({
    required String title,
    String? description,
    DateTime? dueDate,
    String priority = 'medium',
    String? category,
  }) async {
    try {
      final res = await _dio.post('/tasks', data: {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        if (dueDate != null) 'due_date': _ymd(dueDate),
        'priority': priority,
        if (category != null && category.isNotEmpty) 'category': category,
      });
      return TaskModel.fromJson(_asMap(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<TaskModel> update(int id, Map<String, dynamic> patch) async {
    try {
      // Normalise DateTime to YYYY-MM-DD for due_date.
      if (patch['due_date'] is DateTime) {
        patch['due_date'] = _ymd(patch['due_date'] as DateTime);
      }
      final res = await _dio.put('/tasks/$id', data: patch);
      return TaskModel.fromJson(_asMap(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<TaskModel> toggle(int id) async {
    try {
      final res = await _dio.post('/tasks/$id/toggle');
      return TaskModel.fromJson(_asMap(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/tasks/$id');
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<List<TaskTemplateModel>> templates() async {
    try {
      final res = await _dio.get('/task-templates');
      return _asList(res.data).map(TaskTemplateModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<int> importTemplate(int templateId, {DateTime? eventDate}) async {
    try {
      final res = await _dio.post(
        '/task-templates/$templateId/import',
        data: {
          if (eventDate != null) 'event_date': _ymd(eventDate),
        },
      );
      final map = _asMap(res.data);
      return (map['imported'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw toApiException(e);
    }
  }
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
