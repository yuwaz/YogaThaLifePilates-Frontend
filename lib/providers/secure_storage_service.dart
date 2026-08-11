// Add this to your pubspec.yaml:
// dependencies:
//   flutter_secure_storage: ^9.0.0
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/subscription_pending_purchase_correlation.dart';
import '../models/subscription_pending_purchase_intent.dart';
import '../models/subscription_purchase_scope.dart';

class SecureStorageService {
  static const _permissionsKey = 'user_permissions';
  static const _tokenKey = 'jwt_token';
  static const _roleKey = 'user_role';
  static const _salonsKey = 'assigned_salon_ids';
  static const _lastStudioCodeKey = 'last_studio_code';
  static const _pendingPurchasePrefix = 'subscription_pending_purchase_intent';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveAuthData(
    String token,
    String role,
    List<int> salonIds,
  ) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _salonsKey, value: salonIds.join(','));
  }

  Future<void> savePermissions(List<String> permissions) async {
    try {
      final jsonStr = permissions.isEmpty ? '[]' : jsonEncode(permissions);
      await _storage.write(key: _permissionsKey, value: jsonStr);
    } catch (_) {
      await _storage.write(key: _permissionsKey, value: '[]');
    }
  }

  Future<List<String>> getPermissions() async {
    try {
      final str = await _storage.read(key: _permissionsKey);
      if (str == null || str.isEmpty) return [];
      final decoded = jsonDecode(str);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      return [];
    }
    return [];
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<String?> getRole() => _storage.read(key: _roleKey);
  Future<String?> getLastStudioCode() => _storage.read(key: _lastStudioCodeKey);

  Future<void> saveLastStudioCode(String studioCode) async {
    final normalized = studioCode.trim();
    if (normalized.isEmpty) return;
    await _storage.write(key: _lastStudioCodeKey, value: normalized);
  }

  Future<void> clearAuthData() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _salonsKey);
    await _storage.delete(key: _permissionsKey);
  }

  Future<List<int>> getSalonIds() async {
    final ids = await _storage.read(key: _salonsKey);
    if (ids == null || ids.isEmpty) return [];
    return ids
        .split(',')
        .map((e) => int.tryParse(e) ?? 0)
        .where((e) => e != 0)
        .toList();
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }

  String _pendingPurchaseStorageKey(String scopeKey) {
    return '$_pendingPurchasePrefix:$scopeKey';
  }

  Future<List<SubscriptionPendingPurchaseIntent>>
  getPendingPurchaseIntentsForScope(String scopeKey) async {
    final normalizedScopeKey = scopeKey.trim();
    if (!isStableSubscriptionPurchaseScopeKey(normalizedScopeKey)) {
      return const [];
    }

    final key = _pendingPurchaseStorageKey(normalizedScopeKey);
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.trim().isEmpty) {
        return const [];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await _storage.delete(key: key);
        return const [];
      }

      final records = <SubscriptionPendingPurchaseIntent>[];
      for (final item in decoded) {
        final parsed = SubscriptionPendingPurchaseIntent.tryFromJson(item);
        if (parsed != null && parsed.scopeKey == normalizedScopeKey) {
          records.add(parsed);
        }
      }
      return records;
    } catch (_) {
      await _storage.delete(key: key);
      return const [];
    }
  }

  Future<void> savePendingPurchaseIntentsForScope(
    String scopeKey,
    List<SubscriptionPendingPurchaseIntent> records,
  ) async {
    final normalizedScopeKey = scopeKey.trim();
    if (!isStableSubscriptionPurchaseScopeKey(normalizedScopeKey)) {
      return;
    }

    final key = _pendingPurchaseStorageKey(normalizedScopeKey);
    final scopedRecords = records
        .where((record) => record.scopeKey == normalizedScopeKey)
        .toList();

    if (scopedRecords.isEmpty) {
      await _storage.delete(key: key);
      return;
    }

    final encoded = jsonEncode(
      scopedRecords.map((item) => item.toJson()).toList(),
    );
    await _storage.write(key: key, value: encoded);
  }

  Future<void> upsertPendingPurchaseIntent(
    SubscriptionPendingPurchaseIntent record,
  ) async {
    final scopeKey = record.scopeKey.trim();
    if (!isStableSubscriptionPurchaseScopeKey(scopeKey)) {
      return;
    }

    final existing = await getPendingPurchaseIntentsForScope(scopeKey);
    final index = existing.indexWhere(
      (item) => item.purchaseIntentId == record.purchaseIntentId,
    );
    if (index >= 0) {
      existing[index] = record;
    } else {
      existing.add(record);
    }
    await savePendingPurchaseIntentsForScope(scopeKey, existing);
  }

  Future<SubscriptionPendingPurchaseIntent?> getPendingPurchaseIntentById({
    required String scopeKey,
    required String purchaseIntentId,
  }) async {
    final normalizedScopeKey = scopeKey.trim();
    final normalizedIntentId = purchaseIntentId.trim();
    if (!isStableSubscriptionPurchaseScopeKey(normalizedScopeKey) ||
        normalizedIntentId.isEmpty) {
      return null;
    }

    final records = await getPendingPurchaseIntentsForScope(normalizedScopeKey);
    for (final record in records) {
      if (record.purchaseIntentId == normalizedIntentId) {
        return record;
      }
    }
    return null;
  }

  Future<void> updatePendingPurchaseIntentState({
    required String scopeKey,
    required String purchaseIntentId,
    required PendingPurchaseState state,
    String? lastError,
    int? retryCount,
    DateTime? updatedAt,
  }) async {
    final normalizedScopeKey = scopeKey.trim();
    final normalizedIntentId = purchaseIntentId.trim();
    if (!isStableSubscriptionPurchaseScopeKey(normalizedScopeKey) ||
        normalizedIntentId.isEmpty) {
      return;
    }

    final records = await getPendingPurchaseIntentsForScope(normalizedScopeKey);
    final index = records.indexWhere(
      (record) => record.purchaseIntentId == normalizedIntentId,
    );
    if (index < 0) {
      return;
    }

    final existing = records[index];
    records[index] = existing.copyWith(
      state: state,
      lastError: lastError,
      retryCount: retryCount ?? existing.retryCount,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );

    await savePendingPurchaseIntentsForScope(normalizedScopeKey, records);
  }

  Future<void> incrementPendingPurchaseRetryCount({
    required String scopeKey,
    required String purchaseIntentId,
    String? lastError,
    PendingPurchaseState? state,
  }) async {
    final record = await getPendingPurchaseIntentById(
      scopeKey: scopeKey,
      purchaseIntentId: purchaseIntentId,
    );
    if (record == null) {
      return;
    }

    await updatePendingPurchaseIntentState(
      scopeKey: scopeKey,
      purchaseIntentId: purchaseIntentId,
      state: state ?? record.state,
      retryCount: record.retryCount + 1,
      lastError: lastError,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> markPendingPurchaseIntentCompleted({
    required String scopeKey,
    required String purchaseIntentId,
    DateTime? updatedAt,
  }) async {
    await updatePendingPurchaseIntentState(
      scopeKey: scopeKey,
      purchaseIntentId: purchaseIntentId,
      state: PendingPurchaseState.completed,
      retryCount: null,
      lastError: null,
      updatedAt: updatedAt,
    );
  }

  Future<void> markPendingPurchaseIntentFailed({
    required String scopeKey,
    required String purchaseIntentId,
    required String errorCode,
    required bool terminal,
    DateTime? updatedAt,
  }) async {
    final normalizedErrorCode = errorCode.trim();
    await incrementPendingPurchaseRetryCount(
      scopeKey: scopeKey,
      purchaseIntentId: purchaseIntentId,
      lastError: normalizedErrorCode.isEmpty ? null : normalizedErrorCode,
      state: terminal
          ? PendingPurchaseState.verificationFailedTerminal
          : PendingPurchaseState.verificationFailedRetriable,
    );

    if (updatedAt != null) {
      await updatePendingPurchaseIntentState(
        scopeKey: scopeKey,
        purchaseIntentId: purchaseIntentId,
        state: terminal
            ? PendingPurchaseState.verificationFailedTerminal
            : PendingPurchaseState.verificationFailedRetriable,
        lastError: normalizedErrorCode.isEmpty ? null : normalizedErrorCode,
        updatedAt: updatedAt,
      );
    }
  }

  Future<void> removePendingPurchaseIntent({
    required String scopeKey,
    required String purchaseIntentId,
  }) async {
    final normalizedScopeKey = scopeKey.trim();
    final normalizedIntentId = purchaseIntentId.trim();
    if (!isStableSubscriptionPurchaseScopeKey(normalizedScopeKey) ||
        normalizedIntentId.isEmpty) {
      return;
    }

    final records = await getPendingPurchaseIntentsForScope(normalizedScopeKey);
    records.removeWhere(
      (record) => record.purchaseIntentId == normalizedIntentId,
    );
    await savePendingPurchaseIntentsForScope(normalizedScopeKey, records);
  }

  Future<void> clearExpiredPendingPurchaseIntentsForScope(
    String scopeKey,
  ) async {
    final normalizedScopeKey = scopeKey.trim();
    if (!isStableSubscriptionPurchaseScopeKey(normalizedScopeKey)) {
      return;
    }

    final now = DateTime.now().toUtc();
    final records = await getPendingPurchaseIntentsForScope(normalizedScopeKey);
    final updated = <SubscriptionPendingPurchaseIntent>[];
    for (final record in records) {
      if (record.isExpiredAt(now)) {
        continue;
      }
      updated.add(record);
    }

    await savePendingPurchaseIntentsForScope(normalizedScopeKey, updated);
  }

  Future<List<SubscriptionPendingPurchaseIntent>>
  getRecoverablePendingPurchaseIntentsForScope(String scopeKey) async {
    final normalizedScopeKey = scopeKey.trim();
    if (!isStableSubscriptionPurchaseScopeKey(normalizedScopeKey)) {
      return const [];
    }

    await clearExpiredPendingPurchaseIntentsForScope(normalizedScopeKey);
    final now = DateTime.now().toUtc();
    final records = await getPendingPurchaseIntentsForScope(normalizedScopeKey);
    return records.where((record) => record.isRecoverableAt(now)).toList();
  }

  Future<SubscriptionPendingPurchaseCorrelationResult>
  findRecoverableApplePendingPurchaseIntent({
    required String scopeKey,
    required String appAccountToken,
    String? productId,
  }) async {
    return _findRecoverablePendingPurchaseIntent(
      scopeKey: scopeKey,
      provider: PendingPurchaseProvider.appleAppStore,
      identifier: appAccountToken,
      productId: productId,
      identifierSelector: (record) => record.appAccountToken,
    );
  }

  Future<SubscriptionPendingPurchaseCorrelationResult>
  findRecoverableGooglePlayPendingPurchaseIntent({
    required String scopeKey,
    required String obfuscatedAccountId,
    String? productId,
  }) async {
    return _findRecoverablePendingPurchaseIntent(
      scopeKey: scopeKey,
      provider: PendingPurchaseProvider.googlePlay,
      identifier: obfuscatedAccountId,
      productId: productId,
      identifierSelector: (record) => record.obfuscatedAccountId,
    );
  }

  Future<SubscriptionPendingPurchaseCorrelationResult>
  _findRecoverablePendingPurchaseIntent({
    required String scopeKey,
    required PendingPurchaseProvider provider,
    required String identifier,
    required PendingPurchaseIdentifierSelector identifierSelector,
    String? productId,
  }) async {
    final normalizedScopeKey = scopeKey.trim();
    if (!isStableSubscriptionPurchaseScopeKey(normalizedScopeKey)) {
      return const SubscriptionPendingPurchaseCorrelationResult.unavailableScope();
    }

    final records = await getRecoverablePendingPurchaseIntentsForScope(
      normalizedScopeKey,
    );

    return resolvePendingPurchaseCorrelation(
      scopeKey: normalizedScopeKey,
      records: records,
      provider: provider,
      identifier: identifier,
      identifierSelector: identifierSelector,
      productId: productId,
      now: DateTime.now().toUtc(),
    );
  }
}
