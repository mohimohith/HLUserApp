import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/session_manager.dart';
import '../../data/models/home_data.dart';
import '../../data/repositories/repositories.dart';

enum HomeStatus { initial, loading, ready, error }

/// Drives the modern home screen: resolves the active branch, loads the
/// aggregated `/home` payload in one shot, and exposes simple status flags the
/// UI can switch on (shimmer / content / retry).
class HomeController extends ChangeNotifier {
  HomeController({
    HomeRepository? homeRepo,
    BranchRepository? branchRepo,
    SessionManager? session,
  })  : _home = homeRepo ?? Repos.home,
        _branches = branchRepo ?? Repos.branches,
        _session = session ?? SessionManager.instance;

  final HomeRepository _home;
  final BranchRepository _branches;
  final SessionManager _session;

  HomeStatus _status = HomeStatus.initial;
  HomeData? _data;
  String _error = '';

  HomeStatus get status => _status;
  HomeData? get data => _data;
  String get error => _error;
  bool get isLoading => _status == HomeStatus.loading;
  bool get hasData => _data != null;
  String? get branchName => _data?.branchName ?? _session.userName;

  /// Initial load (uses the repository's short cache when warm).
  Future<void> load() async {
    if (_status == HomeStatus.loading) return;
    // Show shimmer only when we have nothing yet; otherwise refresh silently.
    if (_data == null) {
      _status = HomeStatus.loading;
      notifyListeners();
    }
    await _fetch(forceRefresh: false);
  }

  /// Pull-to-refresh: always hit the network.
  Future<void> refresh() => _fetch(forceRefresh: true);

  Future<void> _fetch({required bool forceRefresh}) async {
    try {
      var branchId = _session.branchId;
      if (branchId == null || branchId.isEmpty) {
        final branch = await _branches.resolveActiveBranch();
        branchId = branch?.id;
      }
      if (branchId == null || branchId.isEmpty) {
        _fail('No store is available for your area yet.');
        return;
      }
      _data = await _home.getHome(branchId, forceRefresh: forceRefresh);
      _status = HomeStatus.ready;
      _error = '';
      notifyListeners();
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not load the store. Please try again.');
    }
  }

  void _fail(String message) {
    _error = message;
    // Don't blow away already-rendered content on a background refresh failure.
    _status = _data != null ? HomeStatus.ready : HomeStatus.error;
    notifyListeners();
  }
}
