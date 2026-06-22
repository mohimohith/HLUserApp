import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/format.dart';
import '../../data/models/address.dart';
import '../../data/models/coupon.dart';
import '../../data/repositories/repositories.dart';
import '../address/address_form_sheet.dart';
import '../cart/cart_controller.dart';
import 'order_success_screen.dart';

/// Checkout: choose a delivery address, confirm the bill (computed by the
/// server on placement), and place a COD order.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _couponController = TextEditingController();
  List<DeliveryAddress> _addresses = [];
  DeliveryAddress? _selected;
  CouponValidation? _coupon;
  bool _loading = true;
  bool _placing = false;
  bool _applyingCoupon = false;
  String? _error;
  String? _couponError;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  double get _discount => _coupon?.valid == true ? _coupon!.discount : 0;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _loading = true);
    try {
      final list = await Repos.addresses.list();
      setState(() {
        _addresses = list;
        _selected = list.isNotEmpty
            ? list.firstWhere((a) => a.isDefault, orElse: () => list.first)
            : null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAddress() async {
    final created = await AddressFormSheet.show(context);
    if (created != null) {
      setState(() {
        _addresses = [created, ..._addresses];
        _selected = created;
      });
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    final branchId = SessionManager.instance.branchId;
    final itemsTotal = context.read<CartController>().itemsTotal;
    if (branchId == null) return;
    setState(() {
      _applyingCoupon = true;
      _couponError = null;
    });
    try {
      final result = await Repos.coupons.validate(
        branchId: branchId,
        code: code,
        amount: itemsTotal,
      );
      setState(() {
        if (result.valid) {
          _coupon = result;
          _couponError = null;
        } else {
          _coupon = null;
          _couponError = result.failureMessage;
        }
      });
    } on ApiException catch (e) {
      setState(() {
        _coupon = null;
        _couponError = e.isNotFound ? 'Invalid coupon code' : e.message;
      });
    } finally {
      if (mounted) setState(() => _applyingCoupon = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _coupon = null;
      _couponError = null;
      _couponController.clear();
    });
  }

  Future<void> _placeOrder() async {
    final branchId = SessionManager.instance.branchId;
    if (_selected == null || branchId == null) {
      setState(() => _error = 'Please select a delivery address');
      return;
    }
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final order = await Repos.orders.place(
        branchId: branchId,
        addressId: _selected!.id,
        paymentMethod: 'COD',
        couponCode: _coupon?.valid == true ? _couponController.text.trim() : null,
      );
      if (!mounted) return;
      context.read<CartController>().reset();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: order)),
        (route) => route.isFirst,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>().cart;

    return Scaffold(
      backgroundColor: const Color(0xffF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Checkout',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CheckoutScreen._primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Text('Delivery Address',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addAddress,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(foregroundColor: CheckoutScreen._primary),
                    ),
                  ],
                ),
                if (_addresses.isEmpty)
                  _Card(
                    child: Column(
                      children: [
                        const Text('No saved addresses yet'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _addAddress,
                          child: const Text('Add delivery address'),
                        ),
                      ],
                    ),
                  )
                else
                  ..._addresses.map(_addressTile),
                const SizedBox(height: 20),
                const Text('Apply Coupon',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),
                _couponSection(),
                const SizedBox(height: 20),
                const Text('Bill Summary',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),
                _Card(
                  child: Column(
                    children: [
                      _billRow('Item Total', Money.rupees(cart.itemsTotal)),
                      if (cart.savings > 0)
                        _billRow('Savings', '- ${Money.rupees(cart.savings)}',
                            color: const Color(0xff2E7D32)),
                      if (_discount > 0)
                        _billRow('Coupon Discount', '- ${Money.rupees(_discount)}',
                            color: const Color(0xff2E7D32)),
                      const Divider(height: 20),
                      _billRow(
                          'Payable (COD)',
                          Money.rupees(
                              (cart.itemsTotal - _discount).clamp(0, double.infinity)),
                          bold: true),
                      const SizedBox(height: 6),
                      const Text(
                        'Delivery & handling charges are calculated at confirmation.',
                        style: TextStyle(fontSize: 11, color: Color(0xff999999)),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: Color(0xffE53E3E), fontSize: 13)),
                ],
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _placing ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: CheckoutScreen._primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _placing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Place Order (COD)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _addressTile(DeliveryAddress a) {
    final selected = _selected?.id == a.id;
    return GestureDetector(
      onTap: () => setState(() => _selected = a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? CheckoutScreen._primary : const Color(0xffE5E5E5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? CheckoutScreen._primary : const Color(0xffBBBBBB)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${a.fullAddress}${a.pinCode != null ? ' - ${a.pinCode}' : ''}',
                      style: const TextStyle(fontSize: 12, color: Color(0xff777777))),
                  Text(a.phone,
                      style: const TextStyle(fontSize: 12, color: Color(0xff777777))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _couponSection() {
    final applied = _coupon?.valid == true;
    if (applied) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xffEDF7EE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffBfe3C2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer, color: Color(0xff2E7D32), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Coupon applied — you save ${Money.rupees(_discount)}",
                style: const TextStyle(
                    color: Color(0xff2E7D32), fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: _removeCoupon,
              child: const Text('Remove',
                  style: TextStyle(
                      color: Color(0xffE53E3E), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _couponController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffE5E5E5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffE5E5E5)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _applyingCoupon ? null : _applyCoupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CheckoutScreen._primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _applyingCoupon
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Apply',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        if (_couponError != null) ...[
          const SizedBox(height: 6),
          Text(_couponError!,
              style: const TextStyle(color: Color(0xffE53E3E), fontSize: 12)),
        ],
      ],
    );
  }

  Widget _billRow(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 15 : 13,
      color: color ?? Colors.black,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}
