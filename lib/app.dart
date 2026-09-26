import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/network/network_info.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/home/home_shell.dart';
import 'features/news/data/datasources/news_local_data_source.dart';
import 'features/news/domain/repositories/news_repository.dart';
import 'injection.dart';

class NewsApp extends StatelessWidget {
  const NewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: sl<AuthRepository>()),
        RepositoryProvider<NewsRepository>.value(value: sl<NewsRepository>()),
        RepositoryProvider<NetworkInfo>.value(value: sl<NetworkInfo>()),
      ],
      child: BlocProvider(
        create: (context) =>
            AuthCubit(context.read<AuthRepository>())..checkSession(),
        child: MaterialApp(
          title: 'News App',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: const _AuthGate(),
        ),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E5EFF),
      brightness: brightness,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}

/// Affiche l'écran de connexion ou l'accueil selon l'état d'authentification.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (p, c) =>
          p.status == AuthStatus.authenticated &&
          c.status == AuthStatus.unauthenticated,
      listener: (context, state) {
        // Déconnexion : on ferme les pages empilées et on purge le cache
        // pour ne pas exposer les données au prochain utilisateur.
        Navigator.of(context).popUntil((route) => route.isFirst);
        sl<NewsLocalDataSource>().clear();
      },
      buildWhen: (p, c) => p.status != c.status,
      builder: (context, state) => switch (state.status) {
        AuthStatus.unknown => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        AuthStatus.authenticated => const HomeShell(),
        AuthStatus.unauthenticated => const LoginPage(),
      },
    );
  }
}
