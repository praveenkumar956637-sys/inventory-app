import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Corner radius for fields and buttons.
  static const double radius = 12;

  /// Corner radius for cards and panels.
  static const double cardRadius = 16;

  static const TextTheme _textTheme = TextTheme(
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: AppColors.darkBlack,
      height: 1.2,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.darkBlack,
      height: 1.2,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.darkBlack,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.darkBlack,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.darkBlack,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.darkBlack),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.darkBlack),
    bodySmall: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );

  static ThemeData get lightTheme {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: AppColors.primaryRed,
      onPrimary: AppColors.white,
      secondary: AppColors.green,
      onSecondary: AppColors.white,
      error: AppColors.primaryRed,
      onError: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.darkBlack,
      surfaceTint: Colors.transparent,
      outline: AppColors.border,
    );

    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightGrey,
      textTheme: _textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBlack,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: AppColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.redFaded,
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkBlack,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: AppColors.border),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryRed,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkBlack,
        contentTextStyle: const TextStyle(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryRed,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primaryRed,
        selectionHandleColor: AppColors.primaryRed,
        selectionColor: AppColors.redTint,
      ),
    );
  }

  static OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Shared text field decoration used by the login page, dialogs and search bars.
  static InputDecoration inputDecoration({
    required String label,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textGrey),
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      prefixIconColor: AppColors.textGrey,
      suffixIcon: suffixIcon,
      suffixIconColor: AppColors.textGrey,
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _border(AppColors.border),
      enabledBorder: _border(AppColors.border),
      disabledBorder: _border(AppColors.border),
      focusedBorder: _border(AppColors.primaryRed, 1.5),
      errorBorder: _border(AppColors.primaryRed),
      focusedErrorBorder: _border(AppColors.primaryRed, 1.5),
    );
  }
}
