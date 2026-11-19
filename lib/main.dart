import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/ledger_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/ledger_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {
    // Fallback gracefully if persistence is unavailable (e.g. private browsing).
  }
  final LedgerRepository repository = FirestoreLedgerRepository();
  final AuthService authService = FirestoreAuthService();

  runApp(
    MoazanTradersApp(
      repository: repository,
      authService: authService,
    ),
  );
}

class MoazanTradersApp extends StatefulWidget {
  final LedgerRepository repository;
  final AuthService? authService;

  const MoazanTradersApp({
    super.key,
    required this.repository,
    this.authService,
  });

  @override
  State<MoazanTradersApp> createState() => _MoazanTradersAppState();
}

class _MoazanTradersAppState extends State<MoazanTradersApp> {
  bool _checkingAuth = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    if (widget.authService == null) {
      setState(() {
        _authenticated = true;
        _checkingAuth = false;
      });
      return;
    }
    bool loggedIn = false;
    try {
      loggedIn = await widget.authService!
          .isLoggedIn()
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      loggedIn = false;
    }
    if (mounted) {
      setState(() {
        _authenticated = loggedIn;
        _checkingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = LedgerProvider(repository: widget.repository);
        provider.seedDefaultDealersIfEmpty();
        return provider;
      },
      child: MaterialApp(
        title: 'Moazan Traders - Digital Khata',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: _checkingAuth
            ? const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              )
            : (_authenticated
                ? HomeScreen(
                    authService: widget.authService,
                    onLogout: () => setState(() => _authenticated = false),
                  )
                : LoginScreen(
                    authService: widget.authService!,
                    onLoginSuccess: () =>
                        setState(() => _authenticated = true),
                  )),
      ),
    );
  }
}
