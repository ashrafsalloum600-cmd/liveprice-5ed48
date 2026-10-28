import 'package:flutter/material.dart';

import '../models/nav_item_data.dart';
import '../theme/app_colors.dart';
import '../theme/spring.dart';

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

  static const Duration _duration = Duration(milliseconds: 450);
  static const Curve _curve = AppSpring();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(44)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double labelSpacing = constraints.maxWidth < 520 ? 4 : 8;
          return Row(
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  flex: i == currentIndex ? 4 : 1,
                  child: _NavButton(
                    data: items[i],
                    selected: i == currentIndex,
                    labelSpacing: labelSpacing,
                    showBadge: badgeIndices.contains(i),
                    onTap: () => onTap(i),
                  ),
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
  final double labelSpacing;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavButton({
    required this.data,
    required this.selected,
    required this.labelSpacing,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: PillNavBar._duration,
          curve: PillNavBar._curve,
          height: 44,
          decoration: ShapeDecoration(
            color: selected ? AppColors.surfaceHigh : Colors.transparent,
            shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(34)),
          ),
          child: _NavRow(
            selected: selected,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? data.activeIcon : data.icon,
                    size: 24,
                    color: selected ? AppColors.accent : AppColors.textFaint,
                  ),
                  if (showBadge)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: Color(0xFFFF453A), shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              if (selected) ...[
                SizedBox(width: labelSpacing),
                Flexible(
                  child: Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// الحشوة بمنحنى بدون تجاوز (النابض كان يعطي قيمة سالبة ويكسر assertion)
class _NavRow extends StatelessWidget {
  const _NavRow({required this.selected, required this.children});

  final bool selected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: PillNavBar._duration,
      curve: Curves.easeOutCubic,
      padding: selected ? const EdgeInsets.symmetric(horizontal: 14) : EdgeInsets.zero,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
