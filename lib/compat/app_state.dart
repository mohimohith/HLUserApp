import '../core/session/session_manager.dart';

/// Lightweight global holder for the "ambient" values the legacy screens used to
/// thread through constructors (branchId, userId, delivery-time text).
///
/// The old app passed `int branchId` + `String userId` into every widget and
/// re-fetched the delivery time per card. The new backend resolves the user
/// from the JWT and ships the delivery-time text once in the aggregated `/home`
/// payload, so we cache those here and let the ported widgets read them directly
/// instead of making per-card network calls (this is the bulk of the
/// "load faster" win).
class AppState {
  AppState._();

  /// Active branch id (cuid) resolved at login / splash.
  static String? branchId;

  /// Human-readable branch name (e.g. "KPHB Branch").
  static String? branchName;

  /// "30 Minutes" style text from BranchSettings.deliveryTimeText.
  static String deliveryTimeText = '';

  /// Convenience: the signed-in user's id (empty when logged out).
  static String get userId => SessionManager.instance.userId ?? '';

  static String get branchIdOrEmpty => branchId ?? '';

  static void setBranch(String? id, {String? name}) {
    branchId = id;
    if (name != null) branchName = name;
  }

  static void setDeliveryTime(String text) => deliveryTimeText = text;
}
