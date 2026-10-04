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

  static const double _itemHeight = 56;
  static const double _collapsedWidth = 64;
  static const Duration _duration = Duration(milliseconds: 350);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Row(
              children: [
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    child: _CompactNavButton(
                      data: items[i],
                      selected: i == currentIndex,
                      showBadge: badgeIndices.contains(i),
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            );
          }

          final double expandedWidth = constraints.maxWidth - _collapsedWidth * (items.length - 1);

          return Stack(
            children: [
              AnimatedPositionedDirectional(
                duration: _duration,
                curve: _curve,
                start: currentIndex * _collapsedWidth,
                top: 0,
                width: expandedWidth,
                height: _itemHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0xFFE6E6E6), borderRadius: BorderRadius.circular(28)),
                ),
              ),
              Row(
                children: [
                  for (int i = 0; i < items.length; i++)
                    _NavButton(
                      data: items[i],
                      selected: i == currentIndex,
                      width: i == currentIndex ? expandedWidth : _collapsedWidth,
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

class _CompactNavButton extends StatelessWidget {
  final NavItemData data;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  const _CompactNavButton({required this.data, required this.selected, required this.showBadge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(selected ? data.activeIcon : data.icon, size: 23, color: Colors.black),
                  if (showBadge)
                    Positioned(
                      top: -2,
                      right: -3,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  data.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: selected ? 11 : 10,
                    height: 1.05,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItemData data;
  final bool selected;
  final double width;
  final Duration duration;
  final Curve curve;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavButton({
    required this.data,
    required this.selected,
    required this.width,
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
        child: ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
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
                AnimatedSize(
                  duration: duration,
                  curve: curve,
                  alignment: AlignmentDirectional.centerStart,
                  child: selected
                      ? TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 400),
                          builder: (context, value, child) => Opacity(opacity: value, child: child),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(start: 10),
                            child: Text(
                              data.label,
                              maxLines: 1,
                              style: const TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
