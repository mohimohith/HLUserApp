import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/session_manager.dart';
import '../../data/models/product.dart';
import '../../data/repositories/repositories.dart';
import '../product/product_grid.dart';

/// Full-text product search on `GET /products?search=`. Debounced, paginated,
/// branch-scoped.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<Product> _products = [];

  Timer? _debounce;
  String _query = '';
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      if (q == _query) return;
      _query = q;
      if (q.isEmpty) {
        setState(() {
          _products.clear();
          _searched = false;
          _error = null;
        });
        return;
      }
      _load(reset: true);
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || _query.isEmpty) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _loading = true;
      _searched = true;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _error = null;
      }
    });
    try {
      final branchId = SessionManager.instance.branchId;
      if (branchId == null || branchId.isEmpty) {
        throw const ApiException('No store selected');
      }
      final result = await Repos.products.list(
        branchId: branchId,
        search: _query,
        page: _page,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _products.clear();
        _products.addAll(result.items);
        _hasMore = result.hasNext;
        if (_hasMore) _page += 1;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xffF6F2FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffEADBF2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xff8A8A8A), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Search for groceries, fruits & more',
                    hintStyle: TextStyle(color: Color(0xff8A8A8A), fontSize: 13),
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    _onChanged('');
                  },
                  child: const Icon(Icons.close, color: Color(0xff8A8A8A), size: 18),
                ),
            ],
          ),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (!_searched) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 56, color: Color(0xffCBB7DA)),
            SizedBox(height: 12),
            Text('Search for products',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    if (_loading && _products.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: SearchScreen._primary));
    }
    if (_error != null && _products.isEmpty) {
      return Center(child: Text(_error!, style: const TextStyle(color: Color(0xff666666))));
    }
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_dissatisfied_outlined,
                size: 56, color: Color(0xffCBB7DA)),
            const SizedBox(height: 12),
            Text('No results for "$_query"',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        ProductSliverGrid(products: _products),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: CircularProgressIndicator(color: SearchScreen._primary)),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
