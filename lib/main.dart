import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/connect_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/connectivity_service.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const AuraMonitorApp());
}

class AuraMonitorApp extends StatelessWidget {
  const AuraMonitorApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ChangeNotifierProxyProvider<ConnectivityService, DashboardProvider>(
        create:  (ctx) => DashboardProvider(ctx.read<ConnectivityService>()),
        update:  (_, conn, prev) => prev ?? DashboardProvider(conn),
      ),
    ],
    child: MaterialApp(
      title:          'AuraMonitor Pro',
      theme:          AuraTheme.theme,
      debugShowCheckedModeBanner: false,
      home:           const _RootRouter(),
    ),
  );
}

/// Routes between ConnectScreen and DashboardScreen based on connection state.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityService>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity:  CurvedAnimation(parent: anim, curve: Curves.easeInOut),
        child:    SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: conn.state == ConnectionState.connected
          ? const DashboardScreen(key: ValueKey('dash'))
          : const ConnectScreen(key: ValueKey('connect')),
    );
  }
}
