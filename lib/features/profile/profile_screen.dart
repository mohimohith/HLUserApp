import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/session_manager.dart';
import '../../data/repositories/repositories.dart';
import '../address/address_book_screen.dart';
import '../auth/otp_login_screen.dart';
import '../cart/cart_controller.dart';
import '../orders/orders_screen.dart';
import '../wishlist/wishlist_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    await Repos.auth.logout();
    if (!mounted) return;
    context.read<CartController>().reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OtpLoginScreen()),
      (_) => false,
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _editProfile() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _EditProfileSheet(),
    );
    if (changed == true && mounted) setState(() {});
  }

  void _help() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _HelpSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionManager.instance;
    final name = session.userName ?? 'Guest';
    final phone = session.userPhone ?? '';

    return Scaffold(
      backgroundColor: const Color(0xffF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: const Text('Profile',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: ProfileScreen._primary.withOpacity(0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                        color: ProfileScreen._primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      if (phone.isNotEmpty)
                        Text('+91 $phone',
                            style: const TextStyle(color: Color(0xff777777))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit_outlined,
                      color: ProfileScreen._primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _tile(Icons.receipt_long_outlined, 'My Orders',
              () => _open(const OrdersScreen())),
          _tile(Icons.location_on_outlined, 'Saved Addresses',
              () => _open(const AddressBookScreen())),
          _tile(Icons.favorite_border, 'Wishlist',
              () => _open(const WishlistScreen())),
          _tile(Icons.help_outline, 'Help & Support', _help),
          const SizedBox(height: 12),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Color(0xffE53E3E)),
              title: const Text('Logout',
                  style: TextStyle(
                      color: Color(0xffE53E3E), fontWeight: FontWeight.w600)),
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) => Container(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 1),
        child: ListTile(
          leading: Icon(icon, color: ProfileScreen._primary),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right, color: Color(0xffBBBBBB)),
          onTap: onTap,
        ),
      );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = SessionManager.instance.user;
    _name = TextEditingController(text: user?['name']?.toString() ?? '');
    _email = TextEditingController(text: user?['email']?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Repos.auth.updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
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
          const Text('Edit Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _field(_name, 'Full name'),
          _field(_email, 'Email (optional)',
              keyboard: TextInputType.emailAddress),
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
                backgroundColor: const Color(0xff960ad7),
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
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
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

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Help & Support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.email_outlined, color: Color(0xff960ad7)),
              SizedBox(width: 12),
              Text('support@nexamart.com',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule, color: Color(0xff960ad7)),
              SizedBox(width: 12),
              Text('Mon–Sun, 8 AM – 10 PM',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
