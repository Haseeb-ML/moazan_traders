import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ledger_entry.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/pwa_install_stub.dart'
    if (dart.library.js_interop) '../utils/pwa_install_web.dart';
import '../widgets/entry_form_dialog.dart';
import 'data_tab.dart';
import 'dealers_tab.dart';
import 'recent_entries_tab.dart';
import 'reports_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _tabs = [
    DealersTab(),
    RecentEntriesTab(),
    ReportsTab(),
    DataTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;
    final isCompact = screenWidth < 420;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.jpeg',
                height: 34,
                width: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.storefront,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Moazan Traders',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    provider.isCloudSynced
                        ? 'Kamoke • Online Sync'
                        : 'Kamoke • Local Mode',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isWebPlatform && !isPwaStandalone())
            IconButton(
              tooltip: 'Install App / Add Shortcut',
              icon: const Icon(Icons.install_mobile, color: Colors.white),
              onPressed: () => triggerPwaInstallOrGuide(context),
            ),
          if (!isCompact) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => showEntryFormDialog(
                  context,
                  initialType: EntryType.debit,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Debit'),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8, right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.credit,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => showEntryFormDialog(
                  context,
                  initialType: EntryType.credit,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Credit'),
              ),
            ),
          ] else ...[
            IconButton(
              tooltip: 'New Bill (Debit)',
              icon: const Icon(Icons.add_card, color: Color(0xFFFFCDD2)),
              onPressed: () => showEntryFormDialog(
                context,
                initialType: EntryType.debit,
              ),
            ),
            IconButton(
              tooltip: 'New Wasooli (Credit)',
              icon: const Icon(Icons.payments_outlined,
                  color: Color(0xFFC8E6C9)),
              onPressed: () => showEntryFormDialog(
                context,
                initialType: EntryType.credit,
              ),
            ),
          ],
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('All Khata'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: Text('Cross-Check'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('Reports'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.storage_outlined),
                  selectedIcon: Icon(Icons.storage),
                  label: Text('Data'),
                ),
              ],
            ),
          if (isWide) const VerticalDivider(width: 1),
          Expanded(child: _tabs[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'All Khata',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: 'Cross-Check',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Reports',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storage_outlined),
                  selectedIcon: Icon(Icons.storage),
                  label: 'Data',
                ),
              ],
            ),
    );
  }
}
