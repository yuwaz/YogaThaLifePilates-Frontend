import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../theme/app_design_tokens.dart';

/// Maps a confirmed [AppNotification.type] to a subtle leading icon + color
/// for the Notification Center tiles. Only types confirmed in the codebase
/// (reservation lifecycle + class reminder) get a distinct icon; every other
/// or unknown type falls back to a neutral bell so nothing is invented.
abstract final class NotificationTypeVisual {
  static IconData iconFor(String type) => switch (type) {
    'reservation_created' => Icons.event_available_outlined,
    'reservation_cancelled' || 'reservation_canceled' =>
      Icons.event_busy_outlined,
    'reservation_changed' ||
    'reservation_moved' ||
    'reservation_updated' => Icons.event_note_outlined,
    'class_reminder' || 'reservation_reminder' => Icons.schedule_outlined,
    _ => Icons.notifications_outlined,
  };

  static Color colorFor(String type) => switch (type) {
    'reservation_created' => AppDesignTokens.success,
    'reservation_cancelled' || 'reservation_canceled' =>
      AppDesignTokens.destructive,
    'reservation_changed' ||
    'reservation_moved' ||
    'reservation_updated' => AppDesignTokens.warning,
    'class_reminder' || 'reservation_reminder' =>
      AppDesignTokens.textSecondary,
    _ => AppDesignTokens.textMuted,
  };
}
