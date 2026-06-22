import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../models/home_data.dart';

/// Fetches the aggregated homepage. Keeps a short in-memory mirror of the last
/// payload so returning to the Home tab is instant; the backend itself caches
/// per-branch for 120s, so this only smooths client-side navigation.
class HomeRepository {
  HomeRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  HomeData? _cache;
  String? _cacheBranchId;
  DateTime? _cachedAt;

  HomeData? get cached => _cache;

  bool _isFresh(String branchId) =>
      _cache != null &&
      _cacheBranchId == branchId &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < AppConfig.homeCacheTtl;

  Future<HomeData> getHome(String branchId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _isFresh(branchId)) return _cache!;

    final res = await _api.get<Map<String, dynamic>>(
      '/home',
      query: {'branchId': branchId},
    );
    final data = HomeData.fromJson(res.data);
    _cache = data;
    _cacheBranchId = branchId;
    _cachedAt = DateTime.now();
    return data;
  }

  void invalidate() {
    _cache = null;
    _cachedAt = null;
  }
}
