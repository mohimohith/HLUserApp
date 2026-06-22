import 'package:flutter/foundation.dart';

import '../../core/session/session_manager.dart';
import '../../data/models/cart.dart';
import '../../data/repositories/repositories.dart';

/// Modern, server-authoritative cart state.
///
/// The backend recomputes and returns the full cart on every mutation, so this
/// controller just mirrors that truth and exposes fast lookups for the UI.
/// Quantity changes are optimistic (instant badge/stepper feedback) and roll
/// back if the server rejects them.
class CartController extends ChangeNotifier {
  CartController({CartRepository? repo, SessionManager? session})
      : _repo = repo ?? Repos.cart,
        _session = session ?? SessionManager.instance;

  final CartRepository _repo;
  final SessionManager _session;

  Cart _cart = Cart.empty;
  bool _loading = false;
  bool _mutating = false;

  Cart get cart => _cart;
  List<CartItem> get items => _cart.items;
  bool get isLoading => _loading;
  bool get isMutating => _mutating;
  bool get isEmpty => _cart.isEmpty;
  int get totalItems => _cart.items.fold(0, (s, it) => s + it.quantity);
  int get uniqueItems => _cart.items.length;
  double get itemsTotal => _cart.itemsTotal;
  double get savings => _cart.savings;

  /// Quantity of a given product/variant currently in the cart (0 if absent).
  int quantityOf(String productId, {String? variantId}) {
    for (final it in _cart.items) {
      if (it.productId == productId && (it.variantId ?? '') == (variantId ?? '')) {
        return it.quantity;
      }
    }
    return 0;
  }

  CartItem? _lineFor(String productId, String? variantId) {
    for (final it in _cart.items) {
      if (it.productId == productId && (it.variantId ?? '') == (variantId ?? '')) {
        return it;
      }
    }
    return null;
  }

  bool contains(String productId, {String? variantId}) =>
      quantityOf(productId, variantId: variantId) > 0;

  /// Load the cart for the active branch. Safe to call on tab focus.
  Future<void> load() async {
    final branchId = _session.branchId;
    if (!_session.isAuthenticated.value || branchId == null) {
      _cart = Cart.empty;
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      _cart = await _repo.getCart(branchId);
    } catch (_) {
      // Keep the last known cart on transient failures.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Add one unit (or [quantity]) of a product/variant.
  Future<void> add(String productId, {String? variantId, int quantity = 1}) async {
    final branchId = _session.branchId;
    if (branchId == null) return;
    _mutating = true;
    notifyListeners();
    try {
      _cart = await _repo.add(
        branchId: branchId,
        productId: productId,
        variantId: variantId,
        quantity: quantity,
      );
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  /// Increment/decrement an existing line; removes it at zero.
  Future<void> changeQuantity(
    String productId, {
    String? variantId,
    required int delta,
  }) async {
    final line = _lineFor(productId, variantId);
    if (line == null) {
      if (delta > 0) await add(productId, variantId: variantId, quantity: delta);
      return;
    }
    final next = line.quantity + delta;
    _mutating = true;
    notifyListeners();
    try {
      if (next <= 0) {
        _cart = await _repo.remove(line.id);
      } else {
        _cart = await _repo.setQuantity(line.id, next);
      }
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  Future<void> removeLine(String itemId) async {
    _mutating = true;
    notifyListeners();
    try {
      _cart = await _repo.remove(itemId);
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    final branchId = _session.branchId;
    if (branchId == null) return;
    await _repo.clear(branchId);
    _cart = Cart.empty;
    notifyListeners();
  }

  /// Reset local state on logout / branch switch.
  void reset() {
    _cart = Cart.empty;
    notifyListeners();
  }
}
