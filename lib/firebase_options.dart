// File: lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    // Add mobile/desktop platform options here if needed in the future
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC8Nh7D2haSx9X6K0jyaMaUXrg1qunTIwg',
    authDomain: 'translator-web-app-ca13a.firebaseapp.com',
    projectId: 'translator-web-app-ca13a',
    storageBucket: 'translator-web-app-ca13a.firebasestorage.app',
    messagingSenderId: '773197891693',
    appId: '1:773197891693:web:45dafe83e34395cdd1d764',
  );
}