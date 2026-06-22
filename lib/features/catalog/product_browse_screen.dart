import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/session_manager.dart';
import '../../data/models/catalog.dart';
import '../../data/models/paginated.dart';
import '../../data/models/product.dart';
import '../../data/repositories/repositories.dart';
import '../product/product_grid.dart';

/// A simple {id, name} option used to render sub-category filter chips.
class BrowseChip {
  const BrowseChip({required this.id, required this.name});
  final String id;
  final String name;
}

/// Paginated, infinite-scrolling product grid for a category, brand or tag.
///
/// One [filterKey]/[filterValue] pair scopes the base query (e.g.
/// `mainCategoryId`), while optional [chips] let the user narrow to a child
/// category without leaving the screen.
class ProductBrowseScreen extends StatefulWidget {
  const ProductBrowseScreen({
    super.key,
    required this.title,
    this.mainCategoryId,
    this.categoryId,
    this.subCategoryId,
    this.brandId,
    this.tag,
    this.chips = const [],
  });

  final String title;
  final String? mainCategoryId;
  final String? categoryId;
  final String? subCategoryId;
  final String? brandId;
  final String? tag;

  /// Optional child-category chips (filter by categoryId when selected).
  final List<BrowseChip> chips;

  static const Color _primary = Color(0xff960ad7);

  /// Open a browse screen scoped to a home main-category, exposing its child
  /// categories as filter chips.
  static Future<void> openMainCategory(
      BuildContext context, MainCategory category) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductBrowseScreen(
          title: category.name,
          mainCategoryId: category.id,
          chips: category.categories
              .map((c) => BrowseChip(id: c.id, name: c.name))
              .toList(),
        ),
      ),
    );
  }

  @override
  State<ProductBrowseScreen> createState() => _ProductBrowseScreenState();
}

class _ProductBrowseScreenState extends State<ProductBrowseScreen> {
  final _scroll = ScrollController();
  final List<Product> _products = [];

  String? _selectedCategoryId; // overrides widget.categoryId when a chip is on
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  bool _firstLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categoryId;
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _loading = true;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _error = null;
      }
    });
    try {
      final page = await _fetch(_page);
      if (!mounted) return;
      setState(() {
        if (reset) _products.clear();
        _products.addAll(page.items);
        _hasMore = page.hasNext;
        if (_hasMore) _page += 1;
        _firstLoad = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Paginated<Product>> _fetch(int page) {
    final branchId = SessionManager.instance.branchId;
    if (branchId == null || branchId.isEmpty) {
      throw const ApiException('No store selected');
    }
    return Repos.products.list(
      branchId: branchId,
      mainCategoryId: _selectedCategoryId == null ? widget.mainCategoryId : null,
      categoryId: _selectedCategoryId,
      subCategoryId: widget.subCategoryId,
      brandId: widget.brandId,
      tag: widget.tag,
      page: page,
      limit: 20,
    );
  }

  void _selectChip(String? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _firstLoad = true;
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.title,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          if (widget.chips.isNotEmpty) _chipBar(),
          Expanded(child: _grid()),
        ],
      ),
    );
  }

  Widget _chipBar() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _chip('All', _selectedCategoryId == null, () => _selectChip(null)),
          for (final c in widget.chips)
            _chip(c.name, _selectedCategoryId == c.id, () => _selectChip(c.id)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xff960ad7) : const Color(0xffF3EEF8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? const Color(0xff960ad7) : const Color(0xffE5D8F0)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xff555555))),
        ),
      ),
    );
  }

  Widget _grid() {
    if (_firstLoad && _loading) {
      return const Center(
          child: CircularProgressIndicator(color: ProductBrowseScreen._primary));
    }
    if (_error != null && _products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xff666666))),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: () => _load(reset: true), child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xffCBB7DA)),
            SizedBox(height: 12),
            Text('No products here yet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                  child: CircularProgressIndicator(
                      color: ProductBrowseScreen._primary)),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
