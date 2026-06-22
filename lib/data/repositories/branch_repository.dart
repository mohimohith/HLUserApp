import '../../core/network/api_client.dart';
import '../../core/session/session_manager.dart';
import '../models/branch.dart';

class BranchRepository {
  BranchRepository({ApiClient? client, SessionManager? session})
      : _api = client ?? ApiClient.instance,
        _session = session ?? SessionManager.instance;

  final ApiClient _api;
  final SessionManager _session;

  Future<List<Branch>> list() async {
    final res = await _api.get<List<dynamic>>('/branches');
    return res.data
        .whereType<Map>()
        .map((e) => Branch.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Returns the active branch to serve, persisting it for future sessions.
  /// Falls back to the first active branch until a location-based picker ships.
  Future<Branch?> resolveActiveBranch() async {
    final branches = await list();
    if (branches.isEmpty) return null;
    final selectedId = _session.branchId;
    final picked = branches.firstWhere(
      (b) => b.id == selectedId && b.isActive,
      orElse: () => branches.firstWhere(
        (b) => b.isActive,
        orElse: () => branches.first,
      ),
    );
    await _session.setBranch(picked.id);
    return picked;
  }
}
