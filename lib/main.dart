import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'firebase_options.dart';
import 'screens/auth_page.dart';
import 'screens/session_gate.dart';
import 'screens/student/student_main_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // FIREBASE
  // ============================================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ============================================================
  // FIREBASE APP CHECK
  // ============================================================

  await _activateFirebaseAppCheck();

  // ============================================================
  // SUPABASE
  //
  // Supabase:
  // - Learning-material file storage
  // - Faculty ID document storage
  // - Edge Functions
  //
  // Firebase:
  // - Authentication
  // - Firestore
  // - Firebase AI Logic
  // - App Check
  // ============================================================

  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // ============================================================
  // START APP
  // ============================================================

  runApp(const CASLMSApp());
}

/// Activates Firebase App Check using the provider appropriate
/// for the current platform.
///
/// Web:
/// - Uses reCAPTCHA Enterprise.
/// - Requires FIREBASE_APPCHECK_WEB_SITE_KEY in production.
///
/// Android:
/// - Uses the Firebase debug provider during development.
/// - Uses Play Integrity in release builds.
///
/// Apple and unsupported desktop platforms:
/// - App Check is skipped until those applications are registered.
Future<void> _activateFirebaseAppCheck() async {
  // ============================================================
  // WEB APP CHECK
  // ============================================================

  if (kIsWeb) {
    const webSiteKey = String.fromEnvironment(
      'FIREBASE_APPCHECK_WEB_SITE_KEY',
    );

    if (webSiteKey.isEmpty) {
      if (kReleaseMode) {
        throw StateError(
          'Firebase App Check web site key is missing. '
          'Build the application with '
          '--dart-define=FIREBASE_APPCHECK_WEB_SITE_KEY=YOUR_SITE_KEY',
        );
      }

      debugPrint(
        'Firebase App Check was skipped for local web development '
        'because FIREBASE_APPCHECK_WEB_SITE_KEY was not provided.',
      );

      return;
    }

    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(
        webSiteKey,
      ),
    );

    debugPrint(
      'Firebase App Check activated with reCAPTCHA Enterprise.',
    );

    return;
  }

  // ============================================================
  // ANDROID APP CHECK
  // ============================================================

  if (defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
    );

    debugPrint(
      'Firebase App Check activated for Android using '
      '${kReleaseMode ? 'Play Integrity' : 'the debug provider'}.',
    );

    return;
  }

  // ============================================================
  // APPLE APP CHECK
  // ============================================================

  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    debugPrint(
      'Firebase App Check was not activated because the Apple '
      'application has not been registered in Firebase App Check.',
    );

    return;
  }

  // ============================================================
  // OTHER DESKTOP PLATFORMS
  // ============================================================

  debugPrint(
    'Firebase App Check is not configured for '
    '${defaultTargetPlatform.name}; initialization was skipped.',
  );
}

class CASLMSApp extends StatelessWidget {
  const CASLMSApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSU CAS E-Learning',
      debugShowCheckedModeBanner: false,

      // ========================================================
      // GLOBAL THEME
      // ========================================================

      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blueAccent,
            side: const BorderSide(
              color: Colors.blueAccent,
              width: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.grey[300]!,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Colors.blueAccent,
              width: 2,
            ),
          ),
        ),
      ),

      // ========================================================
      // ROUTING
      // ========================================================

      initialRoute: '/',
      routes: {
        // SessionGate decides whether to display the landing,
        // student, instructor, or administrator interface.
        '/': (context) => const SessionGate(),

        // Login and registration.
        '/auth': (context) => const AuthScreen(),

        // Existing direct student route.
        '/student_dashboard': (context) => const StudentMainScreen(),
      },
    );
  }
}