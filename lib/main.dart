import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/ledger_provider.dart';
import 'screens/home_screen.dart';
import 'services/ledger_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final LedgerRepository repository = FirestoreLedgerRepository();

  runApp(MoazanTradersApp(repository: repository));
}

class MoazanTradersApp extends StatelessWidget {
  final LedgerRepository repository;

  const MoazanTradersApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = LedgerProvider(repository: repository);
        provider.seedDefaultDealersIfEmpty();
        return provider;
      },
      child: MaterialApp(
        title: 'Moazan Traders - Digital Khata',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
