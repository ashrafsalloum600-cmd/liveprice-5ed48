import 'package:flutter/material.dart';
import 'package:liveprice/services/pricing.dart';
import 'package:liveprice/widgets/rate_banner.dart';
import 'package:liveprice/theme/app_colors.dart';

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 24, color: AppColors.text)),
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(left: 6),
            decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.text),
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
              style: const TextStyle(fontSize: 16, color: AppColors.text),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'ابحث باسم المادة أو رمزها',
                hintStyle: TextStyle(color: AppColors.textFaint),
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
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _searching ? _searchRow() : _titleRow(),
        ),
      ),
    );
  }
}
