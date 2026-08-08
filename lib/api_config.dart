// Central API base URL for all environments
// Use this everywhere for API requests
// Change only this value for backend IP/host updates

import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    // Use different base URL for web (Chrome) vs mobile
    if (kIsWeb) {
      // Use window.location.host for same-origin, or set to your backend's public IP/domain
      return 'http://204.168.168.23:3000';
    } else {
      // Use LAN IP for mobile devices on same network
      return 'http://204.168.168.23:3000';
    }
  }
}
