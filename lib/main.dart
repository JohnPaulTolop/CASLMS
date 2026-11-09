import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'core/theme_notifier.dart';
import 'config/supabase_config.dart';
import 'firebase_options.dart';
import 'screens/auth_page.dart';
import 'screens/session_gate.dart';

const bool _caslmsLocalIntegration = bool.fromEnvironment(
  'CASLMS_LOCAL_INTEGRATION',
);
const bool _isUiRedesignMode = bool.fromEnvironment('CASLMS_UI_REDESIGN_MODE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // FIREBASE
  // ============================================================

  if (_caslmsLocalIntegration && (kReleaseMode || !kIsWeb)) {
    throw StateError('Local integration mode supports debug web builds only.');
  }

  await Firebase.initializeApp(
    options: _caslmsLocalIntegration
        ? const FirebaseOptions(
            apiKey: 'local-emulator-only',
            appId: '1:1234567890:web:caslmslocal',
            messagingSenderId: '1234567890',
            projectId: 'demo-caslms-ai-integration',
            authDomain: 'demo-caslms-ai-integration.firebaseapp.com',
          )
        : DefaultFirebaseOptions.currentPlatform,
  );

  if (_caslmsLocalIntegration) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);

    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);

    debugPrint('CASLMS LOCAL INTEGRATION: Firebase emulators enabled.');
  }

  // ============================================================
  // FIREBASE APP CHECK
  // ============================================================

  if (!_caslmsLocalIntegration) {
    await _activateFirebaseAppCheck();
  }

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
    url: _caslmsLocalIntegration
        ? 'http://127.0.0.1:8787'
        : SupabaseConfig.projectUrl,
    publishableKey: _caslmsLocalIntegration
        ? 'local-test-anon-key'
        : SupabaseConfig.publishableKey,
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
/// - Uses the Firebase debug provider in debug builds.
/// - Uses reCAPTCHA Enterprise in profile and release builds.
/// - Requires FIREBASE_APPCHECK_WEB_SITE_KEY outside debug builds.
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
    if (kDebugMode) {
      await FirebaseAppCheck.instance.activate(providerWeb: WebDebugProvider());

      debugPrint(
        'Firebase App Check activated with the web debug provider. '
        'Register the debug token from the browser console in Firebase '
        'Console > App Check > Manage debug tokens.',
      );

      return;
    }

    const webSiteKey = String.fromEnvironment('FIREBASE_APPCHECK_WEB_SITE_KEY');

    if (webSiteKey.isEmpty) {
      throw StateError(
        'Firebase App Check web site key is missing. '
        'Build the application with '
        '--dart-define=FIREBASE_APPCHECK_WEB_SITE_KEY=YOUR_SITE_KEY',
      );
    }

    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(webSiteKey),
    );

    debugPrint('Firebase App Check activated with reCAPTCHA Enterprise.');

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
  const CASLMSApp({super.key});

  static final ThemeNotifier _themeNotifier = ThemeNotifier();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeNotifier,
      builder: (context, _) => MaterialApp(
        title: 'SSU CAS E-Learning',
        debugShowCheckedModeBanner: false,

        // ========================================================
        // GLOBAL THEME
        // ========================================================
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeNotifier.themeMode,

        // ========================================================
        // ROUTING
        // ========================================================
        initialRoute:
            WidgetsBinding.instance.platformDispatcher.defaultRouteName,
        onGenerateRoute: (settings) {
          final uri = Uri.tryParse(settings.name ?? '');
          if (uri?.path == '/notification') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  SessionGate(notificationId: uri!.queryParameters['id']),
            );
          }
          return null;
        },
        routes: {
          // SessionGate decides whether to display the landing,
          // student, instructor, or administrator interface.
          // In UI redesign mode, bypass authentication and go directly to dashboard.
          '/': (context) => SessionGate(isUiRedesignMode: _isUiRedesignMode),

          // Login and registration.
          '/auth': (context) => const AuthScreen(),

          // Legacy URLs must pass the same account/verification gate.
          '/student_dashboard': (context) => const SessionGate(),
        },
      ),
    );
  }
}
