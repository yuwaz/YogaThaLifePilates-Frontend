import 'package:flutter/material.dart';

/// Central semantic visual tokens for the next application-wide theme migration.
/// Existing pages keep their local styles until they are migrated deliberately.
abstract final class AppDesignTokens {
  static const backgroundPrimary = Color(0xFFFAFAFA);
  static const backgroundSecondary = Color(0xFFF3F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF171717);
  static const textSecondary = Color(0xFF525252);
  static const textMuted = Color(0xFF737373);

  static const border = Color(0xFFE5E5E5);
  static const divider = Color(0xFFE5E5E5);

  static const primaryAction = Color(0xFF1F1F1F);
  static const primaryActionForeground = Color(0xFFFFFFFF);
  static const secondaryAction = Color(0xFFFFFFFF);
  static const secondaryActionForeground = Color(0xFF171717);

  static const disabledBackground = Color(0xFFE5E5E5);
  static const disabledForeground = Color(0xFFA3A3A3);
  static const selectedBackground = Color(0xFFE5E5E5);
  static const selectedForeground = Color(0xFF171717);
  static const hoverBackground = Color(0xFFF5F5F5);

  static const destructive = Color(0xFFB42318);
  static const destructiveForeground = Color(0xFFFFFFFF);
  static const success = Color(0xFF18794E);
  static const warning = Color(0xFFA15C00);
  static const error = Color(0xFFB42318);
}

abstract final class AppTypography {
  static const pageTitle = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    color: AppDesignTokens.textPrimary,
  );
  static const sectionTitle = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    color: AppDesignTokens.textPrimary,
  );
  static const cardTitle = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    color: AppDesignTokens.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppDesignTokens.textPrimary,
  );
  static const bodyStrong = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    color: AppDesignTokens.textPrimary,
  );
  static const label = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    color: AppDesignTokens.textSecondary,
  );
  static const button = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    color: AppDesignTokens.primaryActionForeground,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: AppDesignTokens.textMuted,
  );
  static const numericKpi = TextStyle(
    fontSize: 28,
    height: 32 / 28,
    fontWeight: FontWeight.w700,
    color: AppDesignTokens.textPrimary,
  );
}

abstract final class AppButtonStyles {
  static ButtonStyle get primary => ElevatedButton.styleFrom(
    backgroundColor: AppDesignTokens.primaryAction,
    foregroundColor: AppDesignTokens.primaryActionForeground,
    disabledBackgroundColor: AppDesignTokens.disabledBackground,
    disabledForegroundColor: AppDesignTokens.disabledForeground,
    minimumSize: const Size(0, 46),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: AppTypography.button,
  );

  static ButtonStyle get secondary => OutlinedButton.styleFrom(
    backgroundColor: AppDesignTokens.secondaryAction,
    foregroundColor: AppDesignTokens.secondaryActionForeground,
    disabledBackgroundColor: AppDesignTokens.disabledBackground,
    disabledForegroundColor: AppDesignTokens.disabledForeground,
    minimumSize: const Size(0, 46),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    side: const BorderSide(color: AppDesignTokens.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: AppTypography.button.copyWith(
      color: AppDesignTokens.secondaryActionForeground,
    ),
  );

  static ButtonStyle get destructive => ElevatedButton.styleFrom(
    backgroundColor: AppDesignTokens.destructive,
    foregroundColor: AppDesignTokens.destructiveForeground,
    disabledBackgroundColor: AppDesignTokens.disabledBackground,
    disabledForegroundColor: AppDesignTokens.disabledForeground,
    minimumSize: const Size(0, 46),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: AppTypography.button,
  );

  static ButtonStyle get toolbar => secondary.copyWith(
    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
  );

  static ButtonStyle get compactIcon => IconButton.styleFrom(
    foregroundColor: AppDesignTokens.textPrimary,
    disabledForegroundColor: AppDesignTokens.disabledForeground,
    minimumSize: const Size(44, 44),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
}

abstract final class AppIcons {
  static const create = Icons.add;
  static const edit = Icons.edit_outlined;
  static const delete = Icons.delete_outline;
  static const save = Icons.save_outlined;
  static const close = Icons.close;
  static const back = Icons.arrow_back;
  static const search = Icons.search;
  static const filter = Icons.filter_list;
  static const history = Icons.history;
  static const payment = Icons.payment;
  static const settings = Icons.settings;
}
