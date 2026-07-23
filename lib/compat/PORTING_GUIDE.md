# Legacy → New backend porting guide

Goal: present the EXACT old UI (from `php_cust/nexa_mart/lib/...`) but feed data
from the new NestJS backend via the `Repos` layer. Preserve every visual detail
(colors, sizes, paddings, fonts, AppColors, GoogleFonts, ScreenUtil `.h/.w/.sp/.r`,
layout, navigation). Only the DATA PLUMBING changes.

Reference implementation (gold standard): `lib/CustomWidgets/product_card.dart`.

## Hard rules

1. **IDs are Strings (cuid), not ints.** Replace every `int branchId`,
   `int variantId`, `int productId`, `int.tryParse(id)` with `String`. Compare
   ids as strings (`v['id']?.toString() == variantId`).

2. **Branch / user / delivery-time come from `AppState`** (`lib/compat/app_state.dart`):
   - `AppState.branchIdOrEmpty` (String) instead of a threaded `int branchId`.
   - `AppState.userId` (String, from JWT session) instead of SharedPreferences `user_id`.
   - `AppState.deliveryTimeText` instead of fetching `DELIVERY_TIME` per widget.
   Widget constructors may keep `String branchId = ''` / `String userId = ''`
   params, falling back to AppState when empty.

3. **No raw HTTP / ApiConstants / dart:convert.** Remove `package:http`,
   `dart:convert`, `import '../utils/api_constants.dart'`,
   `sendotp_flutter_sdk`, and Razorpay. Use `Repos.*` (import
   `../data/repositories/repositories.dart`).

4. **Images are ABSOLUTE URLs.** The adapters emit full URLs. Replace any
   `ApiConstants.BASE_URL + '/product_api_project/' + img` with just the value
   (`product['images'][0]` / `product['image']`). Keep placeholders/errorBuilder.

5. **Feed legacy widgets via `LegacyAdapters`** (`lib/compat/legacy_adapters.dart`):
   - `LegacyAdapters.product(Product)` → map for ProductCard / SpProduct / detail.
   - `LegacyAdapters.banner / category / subCategory / mainCategory / brand / coupon`.

6. **Cart** uses the shared `CartProvider` (`lib/Provider/cart_provider.dart`):
   - reads unchanged: `getQuantity(userId, pid, vid)`, `getProductTotalQuantity`,
     `getTotalCartItems`, `isInCart`.
   - mutations (async, server-backed):
     `cart.addItem(userId:, branchId:, productId:, variantId:)`,
     `cart.changeQuantity(userId:, branchId:, productId:, variantId:, quantity:)`,
     `cart.removeItem(userId:, branchId:, productId:, variantId:)`,
     `cart.refreshCartData(userId, branchId)`.

7. **Repos map:**
   - `Repos.home.getHome(branchId)` → `HomeData` (one call replaces all home endpoints).
   - `Repos.products.list(branchId:, categoryId?, subCategoryId?, brandId?, search?, page, limit)` → `Paginated<Product>`.
   - `Repos.products.getById(id)` → `Product`.
   - `Repos.branches.list()` / `resolveActiveBranch()`.
   - `Repos.cart.*`, `Repos.orders.place(...)` (COD) / `myOrders()` / `getById()`.
   - `Repos.addresses.*`, `Repos.coupons.validate(...)` / `available(branchId)`,
     `Repos.gifts.list(branchId)`, `Repos.wishlist.list/add/remove/check`.
   - `Repos.auth.requestOtp(phone)` / `verifyOtp(phone:, code:)` / `me()` / `updateProfile()` / `logout()`.

8. **Auth**: OTP via `Repos.auth` (server-side MSG91 Flow). On verify success the
   session is persisted automatically; then resolve branch and go to the shell.

9. **Payments**: COD only. Remove Razorpay; `Repos.orders.place(...)` defaults to COD.

10. **Charges** (cart/checkout) come from `BranchSettings` in `HomeData.settings`:
    `deliveryCharge`, `handlingCharge`, `freeDeliveryThreshold`, `minOrderAmount`,
    `deliveryTimeText`, `helpCallNumber/helpEmail/helpWhatsapp`.

11. Keep `LanguageProvider` (English/Telugu) usage exactly as-is.

12. Use `debugPrint` (not `print`). Guard `setState` with `if (mounted)`.

## Output

A complete, self-contained Dart file at the same relative path under
`nexa_mart/lib/...`, preserving the original class names and public constructors
(adjusting id param types to String). It must reference only existing symbols
from the foundation above.
