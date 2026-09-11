import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../call/providers/call_provider.dart';
import '../../contacts/screens/contacts_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../history/screens/history_screen.dart';
import '../../call/widgets/incoming_call_handler.dart';

import 'home_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Default to dashboard

  final List<Widget> _screens = [
    const HomeDashboardScreen(),
    const ContactsScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return IncomingCallHandler(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ConnectCall'),
          actions: const [],
        ),
        body: _screens[_currentIndex],
        floatingActionButton: Consumer<CallProvider>(
          builder: (context, callProvider, child) {
            final call = callProvider.currentCall;
            if (call != null && (call.status == 'connected' || call.status == 'ringing')) {
              return FloatingActionButton.extended(
                onPressed: () {
                  context.push('/call');
                },
                icon: const Icon(Icons.call, color: Colors.white),
                label: const Text('Return to Call', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green,
              );
            }
            return const SizedBox.shrink();
          },
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'Contacts'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Calls'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

