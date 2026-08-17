import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/home_dashboard.dart';
import 'screens/welcome_screen.dart';
import 'services/backend_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Explicitly set persistence for web/mobile browsers to prevent session drop
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } catch (_) {}

  await NotificationService.init();
  await NotificationService.requestPermissions();
  
  await AppTheme.init();
  runApp(const SplitSmartApp(home: AppEntry()));
}

class SplitSmartApp extends StatelessWidget {
  final Widget home;

  const SplitSmartApp({super.key, this.home = const WelcomeScreen()});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'SplitSmart',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: home,
        );
      },
    );
  }
}

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    if (!BackendService.isFirebaseReady) {
      return const WelcomeScreen();
    }

    // If user is already available synchronously, skip the stream's initial wait
    if (FirebaseAuth.instance.currentUser != null) {
      return const HomeDashboard();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return const WelcomeScreen();
        }

        return const HomeDashboard();
      },
    );
  }
}
