import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Font sizes — ek jaghi change kela ki saglya pages update hotat
// ─────────────────────────────────────────────────────────────────────────────
class AppFontSize {
  AppFontSize._();

  static const double xs      = 10; // tiny labels, badges
  static const double sm      = 12; // captions, hints
  static const double md      = 14; // body text (default)
  static const double lg      = 16; // subtitle, button text
  static const double xl      = 18; // card titles
  static const double xxl     = 20; // screen titles / AppBar
  static const double display = 24; // hero headings
}

// ─────────────────────────────────────────────────────────────────────────────
// Card / layout sizes
// ─────────────────────────────────────────────────────────────────────────────
class AppCardSize {
  AppCardSize._();

  // Border radius
  static const double radiusXs  = 8;
  static const double radiusSm  = 12;
  static const double radiusMd  = 16;
  static const double radiusLg  = 20;
  static const double radiusXl  = 24;

  // Padding inside cards
  static const double paddingSm = 12;
  static const double paddingMd = 16;
  static const double paddingLg = 20;
  static const double paddingXl = 24;

  // Icon container sizes
  static const double iconBoxSm = 36;
  static const double iconBoxMd = 48;
  static const double iconBoxLg = 56;

  // Button height
  static const double buttonHeight = 56;

  // Avatar / image sizes
  static const double avatarSm = 40;
  static const double avatarMd = 56;
  static const double avatarLg = 80;
}

// ─────────────────────────────────────────────────────────────────────────────
// Text styles — AppFontSize use karto, sagalya pages same diste
// ─────────────────────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const String _font = 'Nunito';

  // Display / headings
  static const TextStyle displayLarge = TextStyle(
    fontSize: AppFontSize.display,
    fontWeight: FontWeight.w800,
    fontFamily: _font,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: AppFontSize.xxl,
    fontWeight: FontWeight.w700,
    fontFamily: _font,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: AppFontSize.xl,
    fontWeight: FontWeight.w700,
    fontFamily: _font,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: AppFontSize.lg,
    fontWeight: FontWeight.w600,
    fontFamily: _font,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: AppFontSize.md,
    fontWeight: FontWeight.w400,
    fontFamily: _font,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: AppFontSize.sm,
    fontWeight: FontWeight.w400,
    fontFamily: _font,
  );

  // Labels / captions
  static const TextStyle labelLarge = TextStyle(
    fontSize: AppFontSize.lg,
    fontWeight: FontWeight.w700,
    fontFamily: _font,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: AppFontSize.md,
    fontWeight: FontWeight.w600,
    fontFamily: _font,
  );

  static const TextStyle caption = TextStyle(
    fontSize: AppFontSize.xs,
    fontWeight: FontWeight.w400,
    fontFamily: _font,
  );
}
