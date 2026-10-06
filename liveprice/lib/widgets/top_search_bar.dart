import 'package:flutter/material.dart';
import 'package:liveprice/services/pricing.dart';
import 'package:liveprice/widgets/rate_banner.dart';

class TopSearchBar extends StatefulWidget {
  final VoidCallback onMenu;
  final ValueChanged<String> onChanged;
  final VoidCallback? onAdminLongPress;

  const TopSearchBar({super.key, required this.onMenu, required this.onChanged, this.onAdminLongPress});

  @override
  State<TopSearchBar> createState() => _TopSearchBarState();
}

class _TopSearchBarState extends State<TopSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _controller.clear();
    widget.onChanged('');
    FocusScope.of(context).unfocus();
    setState(() => _searching = false);
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 26, color: Colors.black)),
    );
  }

  Widget _titleRow() {
    return Row(
      key: const ValueKey('title'),
      children: [
        _iconButton(Icons.menu_rounded, widget.onMenu),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: widget.onAdminLongPress,
            child: Center(
              child: AnimatedBuilder(
                animation: Pricing.instance,
                builder: (context, _) => Pricing.instance.usdToSyp == null
                    ? const Text(
                        'My Price',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black),
                      )
                    : const RateBanner(flat: true),
              ),
            ),
          ),
        ),
        _iconButton(Icons.search_rounded, () => setState(() => _searching = true)),
      ],
    );
  }

  Widget _searchRow() {
    return Row(
      key: const ValueKey('search'),
      children: [
        InkResponse(
          onTap: _close,
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(left: 6),
            decoration: const BoxDecoration(color: Color(0xFFE6E6E6), shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, size: 20, color: Colors.black),
          ),
        ),
        Expanded(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              controller: _controller,
              autofocus: true,
              textAlign: TextAlign.center,
              onChanged: widget.onChanged,
              style: const TextStyle(fontSize: 16, color: Colors.black),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'ابحث باسم المادة أو رمزها',
                hintStyle: TextStyle(color: Colors.black45),
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ),
        _iconButton(Icons.search_rounded, () => FocusScope.of(context).unfocus()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: double.infinity,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _searching ? _searchRow() : _titleRow(),
        ),
      ),
    );
  }
}
