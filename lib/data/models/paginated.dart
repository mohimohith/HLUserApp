import 'json_utils.dart';

/// A page of results plus navigation metadata, mirroring the backend's
/// `{ data: [...], meta: {...} }` paginated envelope.
class Paginated<T> {
  final List<T> items;
  final int page;
  final int totalPages;
  final int total;
  final bool hasNext;

  const Paginated({
    required this.items,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.hasNext = false,
  });

  factory Paginated.from(
    List<dynamic> data,
    Map<String, dynamic>? meta,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return Paginated<T>(
      items: data
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      page: asInt(meta?['page'], 1),
      totalPages: asInt(meta?['totalPages'], 1),
      total: asInt(meta?['total']),
      hasNext: asBool(meta?['hasNext']),
    );
  }
}
