import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/address.dart';
import '../../data/repositories/repositories.dart';
import 'address_form_sheet.dart';

/// Manage saved delivery addresses: list, add, edit and delete.
class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  List<DeliveryAddress> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Repos.addresses.list();
      if (mounted) setState(() => _addresses = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final created = await AddressFormSheet.show(context);
    if (created != null) _load();
  }

  Future<void> _edit(DeliveryAddress a) async {
    final updated = await AddressFormSheet.show(context, initial: a);
    if (updated != null) _load();
  }

  Future<void> _delete(DeliveryAddress a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text(a.fullAddress),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xffE53E3E)))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Repos.addresses.remove(a.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Saved Addresses',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AddressBookScreen._primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AddressBookScreen._primary))
          : _error != null
              ? Center(child: Text(_error!))
              : _addresses.isEmpty
                  ? const _Empty()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: _addresses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _AddressTile(
                        address: _addresses[i],
                        onEdit: () => _edit(_addresses[i]),
                        onDelete: () => _delete(_addresses[i]),
                      ),
                    ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.onEdit,
    required this.onDelete,
  });
  final DeliveryAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(address.name,
                  style:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(width: 8),
              if (address.isDefault)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xffF3E9FA),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Default',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xff960ad7),
                          fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined,
                      size: 20, color: Color(0xff777777))),
              const SizedBox(width: 16),
              GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline,
                      size: 20, color: Color(0xffE53E3E))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${address.fullAddress}'
            '${address.landmark != null ? ', ${address.landmark}' : ''}'
            '${address.pinCode != null ? ' - ${address.pinCode}' : ''}',
            style: const TextStyle(fontSize: 13, color: Color(0xff666666)),
          ),
          const SizedBox(height: 2),
          Text(address.phone,
              style: const TextStyle(fontSize: 13, color: Color(0xff666666))),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined, size: 64, color: Color(0xffCBB7DA)),
          SizedBox(height: 16),
          Text('No saved addresses',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
