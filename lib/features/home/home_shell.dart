import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/network_info.dart';
import '../auth/presentation/pages/profile_page.dart';
import '../news/presentation/pages/headlines_page.dart';
import '../news/presentation/pages/search_page.dart';
import '../news/presentation/pages/sources_page.dart';

/// Navigation principale + bandeau global de connectivité.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _online = true;
  StreamSubscription<bool>? _sub;

  static const _pages = [
    HeadlinesPage(),
    SearchPage(),
    SourcesPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    final networkInfo = context.read<NetworkInfo>();
    networkInfo.isConnected.then((v) {
      if (mounted) setState(() => _online = v);
    });
    _sub = networkInfo.onStatusChange.listen((online) {
      if (!mounted) return;
      final wasOffline = !_online;
      setState(() => _online = online);
      if (online && wasOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion rétablie. Tirez pour actualiser.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _online
                ? const SizedBox(width: double.infinity)
                : Material(
                    color: scheme.error,
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Aucune connexion — affichage des données en cache',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onError),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: !_online,
              child: IndexedStack(index: _index, children: _pages),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'À la une',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Recherche',
          ),
          NavigationDestination(
            icon: Icon(Icons.source_outlined),
            selectedIcon: Icon(Icons.source),
            label: 'Sources',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
