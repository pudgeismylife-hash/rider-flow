import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  // Ensure Flutter engine is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: For production Firebase setups, you would run:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // and set up Firebase Cloud Messaging (FCM) callbacks here.

  runApp(
    const ProviderScope(
      child: RiderFlowApp(),
    ),
  );
}
