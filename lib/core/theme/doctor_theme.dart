// import 'package:flutter/material.dart';

// class AppTheme {
//   static const Color primaryBlue = Color(0xFF1A6FD8);
//   static const Color lightBlue = Color(0xFFE8F1FB);
//   static const Color accentGreen = Color(0xFF16A06A);
//   static const Color lightGreen = Color(0xFFE6F7F2);
//   static const Color warningOrange = Color(0xFFF5A623);
//   static const Color lightOrange = Color(0xFFFEF6E8);
//   static const Color errorRed = Color(0xFFE24B4A);
//   static const Color lightRed = Color(0xFFFCEBEB);
//   static const Color surface = Color(0xFFF8F9FC);
//   static const Color cardBg = Colors.white;
//   static const Color textPrimary = Color(0xFF1E2130);
//   static const Color textSecondary = Color(0xFF8F93A1);
//   static const Color borderColor = Color(0xFFEEF0F5);

//   static ThemeData get light => ThemeData(
//         useMaterial3: true,
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: primaryBlue,
//           primary: primaryBlue,
//           surface: surface,
//           background: surface,
//         ),
//         scaffoldBackgroundColor: surface,
//         fontFamily: 'Poppins',
//         appBarTheme: const AppBarTheme(
//           backgroundColor: primaryBlue,
//           foregroundColor: Colors.white,
//           elevation: 0,
//           centerTitle: false,
//         ),
//         cardTheme: CardTheme(
//           color: cardBg,
//           elevation: 0,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//             side: const BorderSide(color: borderColor),
//           ),
//         ),
//         elevatedButtonTheme: ElevatedButtonThemeData(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: primaryBlue,
//             foregroundColor: Colors.white,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             padding: const EdgeInsets.symmetric(vertical: 14),
//             textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//           ),
//         ),
//         inputDecorationTheme: InputDecorationTheme(
//           filled: true,
//           fillColor: surface,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: const BorderSide(color: borderColor),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: const BorderSide(color: borderColor),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: const BorderSide(color: primaryBlue, width: 1.5),
//           ),
//           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//           labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
//         ),
//       );
// }