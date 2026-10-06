import 'package:flutter/material.dart';

import '../models/nav_item_data.dart';

class PillNavBar extends StatelessWidget {
  final List<NavItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Set<int> badgeIndices;

  const PillNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.badgeIndices = const {},
  });

  static const double _collapsedWidth = 64;
  static const Duration _duration = Duration(milliseconds: 350);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobileWidth = constraints.maxWidth < 520;
          final double collapsedWidth = isMobileWidth
              ? (constraints.maxWidth * 0.14).clamp(32.0, _collapsedWidth)
              : _collapsedWidth;
          final double labelSpacing = isMobileWidth ? 4 : 10;
          final double expandedWidth = constraints.maxWidth - collapsedWidth * (items.length - 1);

          return Stack(
            children: [
              Row(
                children: [
                  for (int i = 0; i < items.length; i++)
                    _NavButton(
                      data: items[i],
                      selected: i == currentIndex,
                      width: i == currentIndex ? expandedWidth : collapsedWidth,
                      labelSpacing: labelSpacing,
                      duration: _duration,
                      curve: _curve,
                      showBadge: badgeIndices.contains(i),
                      onTap: () => onTap(i),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItemData data;
  final bool selected;
  final double width;
  final double labelSpacing;
  final Duration duration;
  final Curve curve;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavButton({
    required this.data,
    required this.selected,
    required this.width,
    required this.labelSpacing,
    required this.duration,
    required this.curve,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        width: width,
        height: 56,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: duration,
          curve: curve,
          padding: selected ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6) : EdgeInsets.zero,
          decoration: selected
              ? BoxDecoration(
                  color: const Color(0xFFE6E6E6),
                  border: Border.all(color: const Color(0xFFCECECE), width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      selected ? data.activeIcon : data.icon,
                      key: ValueKey<bool>(selected),
                      size: 28,
                      color: Colors.black,
                    ),
                  ),
                  if (showBadge)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              SizedBox(width: selected ? labelSpacing : 0),
              AnimatedSize(
                duration: duration,
                curve: curve,
                alignment: AlignmentDirectional.centerStart,
                child: selected
                    ? TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 400),
                        builder: (context, value, child) => Opacity(opacity: value, child: child),
                        child: Text(
                          data.label,
                          maxLines: 1,
                          style: const TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
