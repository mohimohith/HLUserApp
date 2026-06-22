import 'address_repository.dart';
import 'auth_repository.dart';
import 'branch_repository.dart';
import 'cart_repository.dart';
import 'coupon_repository.dart';
import 'home_repository.dart';
import 'order_repository.dart';
import 'product_repository.dart';
import 'wishlist_repository.dart';

export 'address_repository.dart';
export 'auth_repository.dart';
export 'branch_repository.dart';
export 'cart_repository.dart';
export 'coupon_repository.dart';
export 'home_repository.dart';
export 'order_repository.dart';
export 'product_repository.dart';
export 'wishlist_repository.dart';

/// Lightweight service locator for the data layer. All repositories are
/// stateless except [HomeRepository] (which holds a short-lived cache), so
/// sharing single instances is safe and avoids prop-drilling.
class Repos {
  Repos._();

  static final AuthRepository auth = AuthRepository();
  static final BranchRepository branches = BranchRepository();
  static final HomeRepository home = HomeRepository();
  static final ProductRepository products = ProductRepository();
  static final CartRepository cart = CartRepository();
  static final AddressRepository addresses = AddressRepository();
  static final OrderRepository orders = OrderRepository();
  static final CouponRepository coupons = CouponRepository();
  static final WishlistRepository wishlist = WishlistRepository();
}
