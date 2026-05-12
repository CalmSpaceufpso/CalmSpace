import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:calm_space/firebase_options.dart';
import 'package:calm_space/providers/psychologist_provider.dart';
import 'package:calm_space/screens/psychologists/psychologist_catalog_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PsychologistProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'CalmSpace',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF6C63FF),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C63FF),
          ),
          useMaterial3: true,
        ),
        home: const PsychologistCatalogScreen(),
      ),
    );
  }
}