import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_translations.dart';
import '../localization/locale_provider.dart';
import '../theme/app_colors.dart';

/// Elderly-friendly, high-contrast language toggle button.
/// Prominently displays [CEB | ENG] allowing one-tap instant switching
/// between Cebuano (Bisaya) and English.
class LanguageSwitchButton extends ConsumerWidget {
  final bool isDark;
  final bool compact;

  const LanguageSwitchButton({
    super.key,
    this.isDark = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(localeProvider);
    final isCeb = currentLang == AppLanguage.cebuano;

    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.surfaceSubtle;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : AppColors.border;

    final activeSegmentBg = isDark ? Colors.white : AppColors.primaryNavy;
    final activeTextColor = isDark ? AppColors.primaryNavy : Colors.white;
    final inactiveTextColor = isDark ? Colors.white70 : AppColors.textMuted;

    if (compact) {
      return Semantics(
        button: true,
        label: isCeb ? 'Balhin sa Iningles' : 'Switch to Cebuano',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ref.read(localeProvider.notifier).toggleLanguage();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.20) : AppColors.primaryNavy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white38 : AppColors.primaryNavy,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isCeb ? 'CEB' : 'ENG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.swap_horiz,
                    size: 13,
                    color: isDark ? Colors.white70 : Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: isCeb ? 'Balhin sa Iningles' : 'Switch to Cebuano',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(localeProvider.notifier).toggleLanguage();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Segment(
                  label: 'CEB',
                  isActive: isCeb,
                  activeBg: activeSegmentBg,
                  activeColor: activeTextColor,
                  inactiveColor: inactiveTextColor,
                ),
                const SizedBox(width: 2),
                _Segment(
                  label: 'ENG',
                  isActive: !isCeb,
                  activeBg: activeSegmentBg,
                  activeColor: activeTextColor,
                  inactiveColor: inactiveTextColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeBg;
  final Color activeColor;
  final Color inactiveColor;

  const _Segment({
    required this.label,
    required this.isActive,
    required this.activeBg,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isActive ? activeColor : inactiveColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
