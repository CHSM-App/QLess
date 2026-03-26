import 'package:flutter/material.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool showClear;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color fillColor;
  final Color borderColor;
  final Color accentColor;
  final Color textColor;
  final Color hintColor;
  final Color iconColor;

  const AppSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.showClear = true,
    this.padding = const EdgeInsets.fromLTRB(12, 6, 12, 7),
    this.backgroundColor = _SearchBarTokens.surface,
    this.fillColor = _SearchBarTokens.bg,
    this.borderColor = _SearchBarTokens.border,
    this.accentColor = _SearchBarTokens.accent,
    this.textColor = _SearchBarTokens.ink,
    this.hintColor = _SearchBarTokens.subtle,
    this.iconColor = _SearchBarTokens.subtle,
  });

  void _handleClear() {
    controller.clear();
    onClear?.call();
    onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      padding: padding,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final showClearIcon = showClear && value.text.isNotEmpty;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            style: TextStyle(fontSize: 12, color: textColor),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: hintColor, fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, size: 15, color: iconColor),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              suffixIcon: showClearIcon
                  ? GestureDetector(
                      onTap: _handleClear,
                      child: Icon(Icons.close_rounded,
                          size: 13, color: iconColor),
                    )
                  : null,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              filled: true,
              fillColor: fillColor,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accentColor, width: 1.2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchBarTokens {
  static const accent = Color(0xFFF97316);
  static const bg = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1A2E);
  static const subtle = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
}
