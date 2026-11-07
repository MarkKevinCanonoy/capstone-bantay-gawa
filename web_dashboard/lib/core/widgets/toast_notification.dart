import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ToastType { success, error, info, warning }

class ToastNotification {
  static OverlayEntry? _activeEntry;
  static _ToastItemState? _activeItemState;

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    // Dismiss any active toast smoothly
    if (_activeEntry != null) {
      _activeItemState?.dismiss();
      _activeEntry = null;
      _activeItemState = null;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      // Fallback if overlay unavailable
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _getFallbackColor(type),
          duration: duration,
        ),
      );
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastItem(
        message: message,
        type: type,
        duration: duration,
        onRegisterState: (state) => _activeItemState = state,
        onDismiss: () {
          if (_activeEntry == entry) {
            try {
              if (entry.mounted) {
                entry.remove();
              }
            } catch (_) {}
            _activeEntry = null;
            _activeItemState = null;
          }
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.error);

  static void warning(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.warning);

  static void info(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.info);

  static Color _getFallbackColor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return const Color(0xFF059669);
      case ToastType.error:
        return const Color(0xFFDC2626);
      case ToastType.warning:
        return const Color(0xFFD97706);
      case ToastType.info:
        return AppColors.primaryNavy;
    }
  }
}

class _ToastItem extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final ValueChanged<_ToastItemState> onRegisterState;
  final VoidCallback onDismiss;

  const _ToastItem({
    required this.message,
    required this.type,
    required this.duration,
    required this.onRegisterState,
    required this.onDismiss,
  });

  @override
  State<_ToastItem> createState() => _ToastItemState();
}

class _ToastItemState extends State<_ToastItem> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.onRegisterState(this);

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _anim.forward();

    _timer = Timer(widget.duration, () {
      dismiss();
    });
  }

  Future<void> dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _anim.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color iconColor;
    Color iconBg;
    IconData icon;

    switch (widget.type) {
      case ToastType.success:
        borderColor = const Color(0xFFA7F3D0); // Emerald 200
        iconColor = const Color(0xFF059669); // Emerald 600
        iconBg = const Color(0xFFECFDF5); // Emerald 50
        icon = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        borderColor = const Color(0xFFFECACA); // Red 200
        iconColor = const Color(0xFFDC2626); // Red 600
        iconBg = const Color(0xFFFEF2F2); // Red 50
        icon = Icons.error_rounded;
        break;
      case ToastType.warning:
        borderColor = const Color(0xFFFDE68A); // Amber 200
        iconColor = const Color(0xFFD97706); // Amber 600
        iconBg = const Color(0xFFFFFBEB); // Amber 50
        icon = Icons.warning_rounded;
        break;
      case ToastType.info:
        borderColor = const Color(0xFFBFDBFE); // Blue 200
        iconColor = const Color(0xFF2563EB); // Royal Blue 600
        iconBg = const Color(0xFFEFF6FF); // Blue 50
        icon = Icons.info_rounded;
        break;
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440, minWidth: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(icon, color: iconColor, size: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: dismiss,
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
