import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/status_views.dart';
import '../cubit/auth_cubit.dart';

/// Écran 5 : profil de l'utilisateur connecté (`GET /api/me`).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().refreshProfile();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez saisir à nouveau vos identifiants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthCubit>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (p, c) =>
            c.errorMessage != null && p.errorMessage != c.errorMessage,
        listener: (context, state) {
          showErrorSnackBar(context, state.errorMessage!);
          context.read<AuthCubit>().clearError();
        },
        builder: (context, state) {
          final user = state.user;
          return RefreshIndicator(
            onRefresh: context.read<AuthCubit>().refreshProfile,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (state.profileFromCache) ...[
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: CachedDataBanner(),
                  ),
                  const SizedBox(height: 16),
                ],
                CircleAvatar(
                  radius: 44,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    _initials(user?.name),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.name ?? 'Profil indisponible hors-ligne',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                if (user != null)
                  Text(
                    user.email,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      if (user?.createdAt != null)
                        ListTile(
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: const Text('Membre depuis'),
                          subtitle: Text(formatDate(user!.createdAt!)),
                        ),
                      ListTile(
                        leading: const Icon(Icons.dns_outlined),
                        title: const Text('Serveur'),
                        subtitle: Text(AppConfig.baseUrl),
                      ),
                      const ListTile(
                        leading: Icon(Icons.public),
                        title: Text('Source des données'),
                        subtitle: Text('NewsAPI.org'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    final letters = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0]);
    return letters.isEmpty ? '?' : letters.join().toUpperCase();
  }
}
