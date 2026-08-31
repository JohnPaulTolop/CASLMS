import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
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
  //
  // DEVELOPMENT:
  // Use the Android debug provider while testing locally.
  //
  // IMPORTANT:
  // Before publishing a release build, change this to:
  //
  // androidProvider: AndroidProvider.playIntegrity,
  //
  // and make sure the Android app is properly registered
  // in Firebase App Check.
  // ============================================================

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  // ============================================================
  // SUPABASE
  //
  // Supabase:
  // Learning-material file storage
  //
  // Firebase:
  // Authentication
  // Firestore
  // Firebase AI Logic
  // App Check
  // ============================================================

  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // ============================================================
  // START APP
  // ============================================================

  runApp(
    const CASLMSApp(),
  );
}

class CASLMSApp extends StatelessWidget {
  const CASLMSApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
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
              borderRadius: BorderRadius.circular(
                8,
              ),
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
              borderRadius: BorderRadius.circular(
                8,
              ),
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,

          fillColor: Colors.white,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              8,
            ),

            borderSide: BorderSide(
              color: Colors.grey[300]!,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              8,
            ),

            borderSide: BorderSide(
              color: Colors.grey[300]!,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              8,
            ),

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
        // MAIN ENTRY POINT
        //
        // SessionGate decides whether the user should see:
        //
        // Landing
        // Student Dashboard
        // Instructor Dashboard
        // Admin Dashboard

        '/': (context) => const SessionGate(),

        // LOGIN / REGISTRATION

        '/auth': (context) => const AuthScreen(),

        // Existing direct student route.
        // SessionGate remains the preferred authentication route.

        '/student_dashboard': (context) =>
            const StudentMainScreen(),
      },
    );
  }
}