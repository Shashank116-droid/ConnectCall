import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'routes/app_router.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/calling_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/contacts/providers/contacts_provider.dart';
import 'features/call/providers/call_provider.dart';
import 'features/history/providers/history_provider.dart';

import 'features/call/widgets/active_call_overlay.dart';

import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final authProvider = AuthProvider(AuthService());
  final appRouter = AppRouter.createRouter(authProvider);
  
  runApp(ConnectCallApp(authProvider: authProvider, router: appRouter));
}

class ConnectCallApp extends StatelessWidget {
  final AuthProvider authProvider;
  final GoRouter router;

  const ConnectCallApp({
    Key? key,
    required this.authProvider,
    required this.router,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ContactsProvider(UserService())),
        ChangeNotifierProvider(create: (_) => CallProvider(CallingService())),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'ConnectCall',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return Stack(
                children: [
                  if (child != null) child,
                  const ActiveCallOverlay(), // The floating PiP widget
                ],
              );
            },
          );
        },
      ),
    );
  }
}
