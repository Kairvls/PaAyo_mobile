import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/report/report_screen.dart';
import 'screens/qr/qr_scanner_screen.dart';
import 'screens/equipment/equipment_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/schedule/schedule_screen.dart';
import 'screens/maintenance/maintenance_screen.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(const PrismMobile());
}

class PrismMobile extends StatelessWidget {
  const PrismMobile({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: "PaAyo",

      theme: AppTheme.lightTheme,

      initialRoute: '/',

      routes: {

        '/': (_) => const SplashScreen(),

        '/home': (_) => const HomeScreen(),

        '/login': (_) => const LoginScreen(),

        '/report': (_) =>  const ReportScreen(),

        '/scanner': (_) => const QRScannerScreen(),

        '/equipment': (_) => const EquipmentScreen(),

        '/history': (_) => const HistoryScreen(),

        '/schedule': (_) => const ScheduleScreen(),

        '/maintenance': (_) => const MaintenanceScreen(),

      },

    );

  }

}