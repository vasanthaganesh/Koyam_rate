import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart'; // To get MainShell
import 'login_screen.dart';

class GuestModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setGuestMode(bool value) => state = value;
}

final guestModeProvider = NotifierProvider<GuestModeNotifier, bool>(GuestModeNotifier.new);

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _isLoading = true;

  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

    // Fallback if stream takes too long (e.g. no internet)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final session = snapshot.data?.session;
        final isGuestMode = ref.watch(guestModeProvider);

        if (session != null || isGuestMode) {
          return const MainShell();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
