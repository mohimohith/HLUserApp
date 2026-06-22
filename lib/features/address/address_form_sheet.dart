import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/address.dart';
import '../../data/repositories/repositories.dart';

/// Reusable bottom sheet to add or edit a delivery address. Returns the saved
/// [DeliveryAddress] via `Navigator.pop`, or null if dismissed.
class AddressFormSheet extends StatefulWidget {
  const AddressFormSheet({super.key, this.initial});

  /// When provided the sheet edits this address instead of creating one.
  final DeliveryAddress? initial;

  static const Color _primary = Color(0xff960ad7);

  static Future<DeliveryAddress?> show(BuildContext context,
      {DeliveryAddress? initial}) {
    return showModalBottomSheet<DeliveryAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddressFormSheet(initial: initial),
    );
  }

  @override
  State<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _pin;
  late final TextEditingController _landmark;
  late bool _isDefault;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _name = TextEditingController(text: a?.name ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _address = TextEditingController(text: a?.fullAddress ?? '');
    _pin = TextEditingController(text: a?.pinCode ?? '');
    _landmark = TextEditingController(text: a?.landmark ?? '');
    _isDefault = a?.isDefault ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _pin.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().length < 10 ||
        _address.text.trim().length < 3) {
      setState(() => _error = 'Please fill name, valid phone and address');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final name = _name.text.trim();
      final phone = _phone.text.trim();
      final full = _address.text.trim();
      final pin = _pin.text.trim().isEmpty ? null : _pin.text.trim();
      final landmark = _landmark.text.trim().isEmpty ? null : _landmark.text.trim();

      final DeliveryAddress saved;
      if (_isEdit) {
        saved = await Repos.addresses.update(widget.initial!.id, {
          'name': name,
          'phone': phone,
          'fullAddress': full,
          if (pin != null) 'pinCode': pin,
          if (landmark != null) 'landmark': landmark,
          'isDefault': _isDefault,
        });
      } else {
        saved = await Repos.addresses.create(
          name: name,
          phone: phone,
          fullAddress: full,
          pinCode: pin,
          landmark: landmark,
          isDefault: _isDefault,
        );
      }
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEdit ? 'Edit Address' : 'Add Address',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _field(_name, 'Full name'),
          _field(_phone, 'Phone number', keyboard: TextInputType.phone),
          _field(_address, 'Full address', maxLines: 2),
          Row(
            children: [
              Expanded(
                  child:
                      _field(_pin, 'Pin code', keyboard: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _field(_landmark, 'Landmark (optional)')),
            ],
          ),
          CheckboxListTile(
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AddressFormSheet._primary,
            title: const Text('Set as default address',
                style: TextStyle(fontSize: 13)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!,
                style: const TextStyle(color: Color(0xffE53E3E), fontSize: 13)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AddressFormSheet._primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Update Address' : 'Save Address',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint,
      {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xffF6F2FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
