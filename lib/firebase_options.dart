// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCIqM3mgZF1BBBLT0ewExtfDJBclSEuoH4',
    appId: '1:1049916225602:web:d66c002fed2d915b6a55db',
    messagingSenderId: '1049916225602',
    projectId: 'website-2be73',
    authDomain: 'website-2be73.firebaseapp.com',
    storageBucket: 'website-2be73.appspot.com',
    measurementId: 'G-6LQQHBC6C2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCIqM3mgZF1BBBLT0ewExtfDJBclSEuoH4',
    appId: '1:1049916225602:web:d66c002fed2d915b6a55db',
    messagingSenderId: '1049916225602',
    projectId: 'website-2be73',
    storageBucket: 'website-2be73.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCIqM3mgZF1BBBLT0ewExtfDJBclSEuoH4',
    appId: '1:1049916225602:web:d66c002fed2d915b6a55db',
    messagingSenderId: '1049916225602',
    projectId: 'website-2be73',
    storageBucket: 'website-2be73.appspot.com',
    iosBundleId: 'com.example.raps', // change this if needed
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCIqM3mgZF1BBBLT0ewExtfDJBclSEuoH4',
    appId: '1:1049916225602:web:d66c002fed2d915b6a55db',
    messagingSenderId: '1049916225602',
    projectId: 'website-2be73',
    storageBucket: 'website-2be73.appspot.com',
    iosBundleId: 'com.example.raps', // change if necessary
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCIqM3mgZF1BBBLT0ewExtfDJBclSEuoH4',
    appId: '1:1049916225602:web:d66c002fed2d915b6a55db',
    messagingSenderId: '1049916225602',
    projectId: 'website-2be73',
    authDomain: 'website-2be73.firebaseapp.com',
    storageBucket: 'website-2be73.appspot.com',
    measurementId: 'G-6LQQHBC6C2',
  );
}
