import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum ActionFeedback {
  reservationCreate,
  reservationUpdate,
  reservationMove,
  reservationDelete,
  attendanceCreate,
  attendanceUpdate,
  attendanceDelete,
  memberCreate,
  memberUpdate,
  memberDeactivate,
  memberReactivate,
  paymentCreate,
  paymentUpdate,
  paymentDelete,
  expenseCreate,
  expenseUpdate,
  expenseDelete,
  lessonPackageCreate,
  lessonPackageUpdate,
  lessonPackageDelete,
  manualCardUsageCreate,
  manualCardUsageUpdate,
  manualCardUsageDelete,
  measurementCreate,
  passwordChange,
  instructorCreate,
  instructorUpdate,
  instructorDelete,
  instructorPasswordUpdate,
  instructorFeesUpdate,
  memberTypeCreate,
  memberTypeUpdate,
  memberTypeDelete,
  paymentMethodCreate,
  paymentMethodUpdate,
  paymentMethodDelete,
  salonCreate,
  salonUpdate,
  salonDelete,
  equipmentCreate,
  equipmentUpdate,
  equipmentDelete,
  assignedPackageRemove,
  onboardingSetup,
  login,
}

String actionSuccessMessage(BuildContext context, ActionFeedback action) {
  return _translate(context, '${_key(action)}Success');
}

String actionFailureMessage(
  BuildContext context,
  ActionFeedback action, [
  Object? error,
]) {
  final knownReason = _knownReasonKey(error);
  final reason = knownReason ?? 'feedbackReasonTryAgain';
  return '${_translate(context, '${_key(action)}Failure')} ${_translate(context, reason)}';
}

String _translate(BuildContext context, String key) {
  return AppLocalizations.of(context)?.translate(key) ?? key;
}

String _key(ActionFeedback action) {
  return switch (action) {
    ActionFeedback.reservationCreate => 'reservationCreate',
    ActionFeedback.reservationUpdate => 'reservationUpdate',
    ActionFeedback.reservationMove => 'reservationMove',
    ActionFeedback.reservationDelete => 'reservationDelete',
    ActionFeedback.attendanceCreate => 'attendanceCreate',
    ActionFeedback.attendanceUpdate => 'attendanceUpdate',
    ActionFeedback.attendanceDelete => 'attendanceDelete',
    ActionFeedback.memberCreate => 'memberCreate',
    ActionFeedback.memberUpdate => 'memberUpdate',
    ActionFeedback.memberDeactivate => 'memberDeactivate',
    ActionFeedback.memberReactivate => 'memberReactivate',
    ActionFeedback.paymentCreate => 'paymentCreate',
    ActionFeedback.paymentUpdate => 'paymentUpdate',
    ActionFeedback.paymentDelete => 'paymentDelete',
    ActionFeedback.expenseCreate => 'expenseCreate',
    ActionFeedback.expenseUpdate => 'expenseUpdate',
    ActionFeedback.expenseDelete => 'expenseDelete',
    ActionFeedback.lessonPackageCreate => 'lessonPackageCreate',
    ActionFeedback.lessonPackageUpdate => 'lessonPackageUpdate',
    ActionFeedback.lessonPackageDelete => 'lessonPackageDelete',
    ActionFeedback.manualCardUsageCreate => 'manualCardUsageCreate',
    ActionFeedback.manualCardUsageUpdate => 'manualCardUsageUpdate',
    ActionFeedback.manualCardUsageDelete => 'manualCardUsageDelete',
    ActionFeedback.measurementCreate => 'measurementCreate',
    ActionFeedback.passwordChange => 'passwordChange',
    ActionFeedback.instructorCreate => 'instructorCreate',
    ActionFeedback.instructorUpdate => 'instructorUpdate',
    ActionFeedback.instructorDelete => 'instructorDelete',
    ActionFeedback.instructorPasswordUpdate => 'instructorPasswordUpdate',
    ActionFeedback.instructorFeesUpdate => 'instructorFeesUpdate',
    ActionFeedback.memberTypeCreate => 'memberTypeCreate',
    ActionFeedback.memberTypeUpdate => 'memberTypeUpdate',
    ActionFeedback.memberTypeDelete => 'memberTypeDelete',
    ActionFeedback.paymentMethodCreate => 'paymentMethodCreate',
    ActionFeedback.paymentMethodUpdate => 'paymentMethodUpdate',
    ActionFeedback.paymentMethodDelete => 'paymentMethodDelete',
    ActionFeedback.salonCreate => 'salonCreate',
    ActionFeedback.salonUpdate => 'salonUpdate',
    ActionFeedback.salonDelete => 'salonDelete',
    ActionFeedback.equipmentCreate => 'equipmentCreate',
    ActionFeedback.equipmentUpdate => 'equipmentUpdate',
    ActionFeedback.equipmentDelete => 'equipmentDelete',
    ActionFeedback.assignedPackageRemove => 'assignedPackageRemove',
    ActionFeedback.onboardingSetup => 'onboardingSetup',
    ActionFeedback.login => 'login',
  };
}

String? _knownReasonKey(Object? error) {
  final message = error?.toString().trim().toLowerCase() ?? '';
  if (message.isEmpty) return null;
  if (message.contains('phone number must start with +90')) {
    return 'feedbackReasonTurkishPhone';
  }
  if (message.contains('invalid credentials') ||
      message.contains('invalid email or password')) {
    return 'feedbackReasonInvalidCredentials';
  }
  if (message.contains('no auth token') ||
      message.contains('unauthorized') ||
      message.contains('forbidden') ||
      message.contains('status code: 401') ||
      message.contains('status code: 403')) {
    return 'feedbackReasonSessionExpired';
  }
  if (message.contains('status code: 400') || message.contains('bad request')) {
    return 'feedbackReasonInvalidRequest';
  }
  if (message.contains('status code: 404') || message.contains('not found')) {
    return 'feedbackReasonNotFound';
  }
  if (message.contains('socketexception') ||
      message.contains('timeout') ||
      message.contains('connection refused')) {
    return 'feedbackReasonNetwork';
  }
  return null;
}
