// Central API base URL for all environments
// Use this everywhere for API requests
// Change only this value for backend IP/host updates

import 'package:flutter/foundation.dart';

class ApiConfig {
  static const mobileProductionBaseUrl = 'http://204.168.168.23:3000';
  static const webDevApiEnabled = bool.fromEnvironment(
    'YOGATHA_WEB_DEV_API',
    defaultValue: false,
  );

  static String resolveBaseUrl(bool isWeb, {bool webDevApi = false}) {
    if (!isWeb) return mobileProductionBaseUrl;
    return webDevApi ? mobileProductionBaseUrl : '/api';
  }

  static String get baseUrl =>
      resolveBaseUrl(kIsWeb, webDevApi: webDevApiEnabled);
}
