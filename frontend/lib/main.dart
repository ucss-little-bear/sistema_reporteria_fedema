import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/View/app_theme.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Controller/reporte_provider_controller.dart';
import 'package:frontend/Controller/usuario_provider_controller.dart';
import 'View/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        ChangeNotifierProvider(create: (_) => ReporteProvider()),

        ChangeNotifierProvider(create: (_) => UsuarioProvider()),
      ],
      child: MaterialApp(
        title: 'Sistema Académico ERP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,

        home: const LoginScreen(),
      ),
    );
  }
}
