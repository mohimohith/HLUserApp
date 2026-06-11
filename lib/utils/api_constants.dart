class ApiConstants {

  static const String BASE_URL = "https://mlands-nexamart.com/api_folder";

  // Auth
  static const String SEND_OTP = "$BASE_URL/auth/user_login.php";
  static const String OTP_VERIFICATION = "$BASE_URL/auth/verify_otp.php";
  static const String GET_USER = "$BASE_URL/auth/get_user.php";
  static const String EDIT_PROFILE = "$BASE_URL/auth/edit_profile.php";
  static const String ADD_USER = "$BASE_URL/auth/add_user.php";
  static const String VIEW_BRANCH = "$BASE_URL/branch_api/view_branch_with_location.php";



  // Brand
  static const String VIEW_BRAND = "$BASE_URL/brand_api/view_brand.php";


  // DeliveryTime
  static const String DELIVERY_TIME = "$BASE_URL/deliver_time/get_delivery_time.php";
  static const String VIEW_GIFT = "$BASE_URL/gift/get_single_gift.php";



  // Category
  static const String VIEW_MAIN_CATEGORY_CATEGORY = "$BASE_URL/main_category/all_main_category_with_category.php";
  static const String VIEW_SUB_CATEGORY = "$BASE_URL/sub_category_api/view_sub_category.php";

  static const String MAIN_VIEW_CATEGORY = "$BASE_URL/main_category/view.php";

  static const String VIEW_CATEGORY_WITH_MAIN_CATEGOTY_ID = "$BASE_URL/category_api/view_category_with_main_category_id.php";
  static const String VIEW_TOP_CATEGORY = "$BASE_URL/top_category_api/view_banner.php";
  static const String GET_MAIN_CATEGORY_WITH_POSITION = "$BASE_URL/main_category/get_main_categories_with_position.php";


  // Product
  static const String VIEW_PRODUCTS_BY_SUBCATEGORY = "$BASE_URL/product_api_project/product/get_products_by_subcategory.php";
  static const String VIEW_ALL_PRODUCTS_BY_CATEGORY = "$BASE_URL/product_api_project/product/get_all_products_by_category.php";
  static const String VIEW_PRODUCT_BY_TYPE = "$BASE_URL/product_api_project/product/get_product_by_type.php";
  static const String VIEW_ALL_PRODUCTS = "$BASE_URL/product_api_project/product/get_all_products.php";



  // Location
  static const String VIEW_DISTRICT = "$BASE_URL/location/district/view_district.php";
  static const String VIEW_CITY = "$BASE_URL/location/city/view_city.php";


  // Banner
  static const String OCCASION_BANNER = "$BASE_URL/occasion_banner_api/get_single_occasion_banner.php";
  static const String OFFER_BANNER = "$BASE_URL/offer_banner_api/view_banner.php";
  static const String VIEW_SLIDER = "$BASE_URL/banner_api/view_banner.php";


  static const String DISCOUTN_BANNER = "$BASE_URL/discount_banner_api/get_single_discount_banner.php";
  static const String BOTTOM_BANNER = "$BASE_URL/bottom_banner/get_single_discount_banner.php";
  static const String MIDDLE_BANNER = "$BASE_URL/middle_banner/get_single_discount_banner.php";
  static const String HOME_BANNER = "$BASE_URL/home_banner/get_single_discount_banner.php";


  //Coupon Code
  static const String VIEW_COUPON = "$BASE_URL/coupon_code_api/view_coupon.php";
  static const String VALIDATE_COUPON = "$BASE_URL/coupon_code_api/validate_coupon.php";


  static const String VIEW_OCCASION_CATEGORY = "$BASE_URL/occasion_category_api/view_banner.php";


  // Cart item
  static const String ADD_TO_CART = "$BASE_URL/product_api_project/cart/add_to_cart.php";
  static const String GET_CART_ITEMS = "$BASE_URL/product_api_project/cart/get_cart_items.php";
  static const String UPDATE_QUANTITY = "$BASE_URL/product_api_project/cart/update_quantity.php";
  static const String REMOVE_CART_ITEM = "$BASE_URL/product_api_project/cart/remove_from_cart.php";


  // Place Order
  static const String PLACE_ORDER = "$BASE_URL/product_api_project/place_order/place_order.php";
  static const String GET_ORDER_BY_USER = "$BASE_URL/product_api_project/place_order/get_order_by_user.php";

  // Razorpay Auto Capture Payment
  static const String RAZORPAY_AUTO_CAPTURE_AMOUNT = "$BASE_URL/product_api_project/place_order/razorpay_capture.php";


  // Delivery Address
  static const String ADD_ADDRESS = "$BASE_URL/delivery_address/add_address.php";
  static const String VIEW_ADDRESS = "$BASE_URL/delivery_address/view_address.php";
  static const String UPDATE_ADDRESS = "$BASE_URL/delivery_address/address_edit.php";
  static const String DELETE_ADDRESS = "$BASE_URL/delivery_address/delete_address.php";


  // Wishlist
  static const String ADD_TO_WISHLIST = "$BASE_URL/wishlist/add_to_wishlist.php";
  static const String CHECK_WISHLIST = "$BASE_URL/wishlist/check_wishlist.php";
  static const String REMOVE_FROM_WISHLIST = "$BASE_URL/wishlist/remove_from_wishlist.php";
  static const String GET_WISHLIST = "$BASE_URL/wishlist/get_wishlist.php";


  // Help
  static const String GET_CALLING_NUMBER = "$BASE_URL/help_api/call/get_help_call.php";
  static const String GET_WHATSAPP_NUMBER = "$BASE_URL/help_api/whatsapp/get_help_whatsapp.php";
  static const String GET_EMAIL = "$BASE_URL/help_api/email/get_help_email.php";


  // Delivery Charge
  static const String FETCH_DELIVERY_AMOUNT = "$BASE_URL/delivery_charge/get_delivery_charge.php";

  // Minimum order Amount
  static const String GET_MINIMUM_ORDER_AMOUT = "$BASE_URL/minimum_order_amout/get_ minimum_order_amout.php";


  // Handling Charge
  static const String GET_HANDLING_CHARGE = "$BASE_URL/handling_charge/get_delivery_charge.php";

  // Free Delivery Amount
  static const String GET_FREE_DELIVERY_AMOUNT = "$BASE_URL/free_delivey/get_free_delivery.php";



  // Product
  static const String SPECIAL_CATEGORY_PRODUCTS = "$BASE_URL/special_category_products/special_category_products.php";
  static const String VIEW_SPECIAL_CATEGORY = "$BASE_URL/special_category/view_banner.php";


  static const String VIEW_BEST_SELLIGN_CATEGORY = "$BASE_URL/best_selling_category/view_banner.php";

  static const String BEST_SELLIGN_PRODUCTS = "$BASE_URL/best_selling_product/special_category_products.php";



  static const String VIEW_SECTION = "$BASE_URL/section_api/view_section.php";
  static const String VIEW_PRODUCT_BY_SECTION = "$BASE_URL/product_api_project/product/get_products_by_section.php";

}


