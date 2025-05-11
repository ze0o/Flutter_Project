import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'admin_home_page.dart';
import 'admin_accident_reports_page.dart';
import 'admin_insurance_management.dart';
import 'vehicle_registration_page.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyBrPvKdNX28B85l9ynlecMYrHRYskFjHGc",
      authDomain: "itcs444-proj.firebaseapp.com",
      projectId: "itcs444-proj",
      storageBucket: "itcs444-proj.appspot.com",
      messagingSenderId: "603532184988",
      appId: "1:603532184988:web:a5c386220a3d5878024c59",
      measurementId: "G-KMNRLWK9X6",
    ),
  );

  // Initialize notification service
  await NotificationService.initialize();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Insurance App',
      theme: AppTheme.lightTheme,
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/admin_accident_reports': (context) => AdminAccidentReportsPage(),
        '/admin_insurance_management':
            (context) => AdminInsuranceManagementPage(),
        '/vehicle_registration': (context) => VehicleRegistrationPage(),
        // Removed the direct PaymentPage route since it requires parameters
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/car_logo.png',
                      width: 120,
                      height: 120,
                    ),
                    SizedBox(height: 24),
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasData) {
          // Save device token for notifications
          NotificationService.saveDeviceToken();

          return FutureBuilder<DocumentSnapshot>(
            future:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(snapshot.data!.uid)
                    .get(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return Scaffold(
                  body: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                );
              }
              final userData = userSnapshot.data!;
              if (userData.exists && userData['role'] == 'Admin') {
                return AdminHomePage();
              } else {
                return HomePage();
              }
            },
          );
        } else {
          return LoginPage();
        }
      },
    );
  }
}
