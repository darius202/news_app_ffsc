# News App — Flutter + backend JWT + NewsAPI

Application Flutter d'actualités connectée à un backend Dart qui gère
l'authentification JWT (access + refresh token) et relaie les appels à
[NewsAPI](https://newsapi.org).

```
┌──────────────┐  Bearer JWT   ┌──────────────────────┐  X-Api-Key  ┌──────────┐
│ App Flutter  │ ────────────▶ │ server/ (Dart shelf) │ ──────────▶ │ NewsAPI  │
│ Dio + Hive   │ ◀──────────── │ auth + proxy news    │ ◀────────── │          │
└──────────────┘               └──────────────────────┘             └──────────┘
```

Pourquoi un backend ? NewsAPI n'a pas d'authentification utilisateur. Le
backend fournit register/login/refresh/logout en JWT et garde la clé NewsAPI
côté serveur, pour qu'elle ne soit jamais embarquée dans l'APK.

## Fonctionnalités

| Exigence | Implémentation |
|---|---|
| Authentification login/register/logout (JWT) | `features/auth` + `server/lib/src/auth_service.dart` |
| Au moins 3 écrans de données API | À la une (par catégorie), Recherche, Sources, Articles d'une source, Profil (`/api/me`) |
| Cache local | Hive (`news_cache`, `auth_cache`), tokens dans `flutter_secure_storage` |
| Mode hors-ligne | Repli automatique sur le cache + bandeau « données du JJ/MM HH:MM » |
| Erreurs réseau | `dio_error_mapper.dart` → `Failure` avec message en français, écran « Réessayer », SnackBars |
| Clean Architecture | `data/` · `domain/` · `presentation/` par feature |
| Repository pattern | `AuthRepository`, `NewsRepository` (interfaces dans `domain`, implémentations dans `data`) |
| Dio | `core/network/dio_client.dart` |
| Intercepteur de token | `core/network/auth_interceptor.dart` |
| Refresh token | Sur 401 : refresh, rotation du refresh token, rejeu de la requête ; si le refresh échoue, déconnexion |
| Tests unitaires | 21 tests : repositories auth et news, intercepteur |

## Lancer le projet

### 1. Backend

Créez une clé gratuite sur <https://newsapi.org/register>, puis copiez
`server/.env.example` en `server/.env` et renseignez `NEWSAPI_KEY` et
`JWT_SECRET` (ce fichier est ignoré par git) :

```bash
cd server
dart pub get
dart run bin/server.dart
```

Les variables d'environnement système sont prioritaires sur le `.env`.

Le serveur écoute sur `http://localhost:8080`. Pour voir le refresh token
fonctionner, raccourcissez la durée de l'access token :
`ACCESS_TTL_SECONDS=30`.

| Méthode | Route | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | — | `{name, email, password}` → tokens + user |
| POST | `/auth/login` | — | `{email, password}` → tokens + user |
| POST | `/auth/refresh` | — | `{refreshToken}` → nouveau couple (rotation) |
| POST | `/auth/logout` | — | `{refreshToken}` → révocation |
| GET | `/api/me` | Bearer | profil |
| GET | `/api/news/top-headlines` | Bearer | proxy NewsAPI |
| GET | `/api/news/everything` | Bearer | proxy NewsAPI |
| GET | `/api/news/sources` | Bearer | proxy NewsAPI |

### 2. Application

```bash
flutter pub get
flutter run
```

L'URL du backend est choisie automatiquement : `10.0.2.2:8080` sur
l'émulateur Android, `localhost:8080` ailleurs. Sur un téléphone physique,
utilisez l'IP de votre PC :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080
```

### 3. Tests

```bash
flutter test
```

## Architecture

```
lib/
├── core/
│   ├── config/        AppConfig (URL, timeouts, pagination)
│   ├── error/         AppException (data) → Failure (domain)
│   ├── network/       Dio, AuthInterceptor, mapping des erreurs, NetworkInfo
│   ├── storage/       TokenStorage (secure storage)
│   ├── utils/         Result<T> (Success / ResultFailure), dates
│   └── widgets/       ErrorView, EmptyView, CachedDataBanner
├── features/
│   ├── auth/
│   │   ├── data/          remote (Dio), local (Hive), models, AuthRepositoryImpl
│   │   ├── domain/        User, AuthRepository
│   │   └── presentation/  AuthCubit, Login, Register, Profil
│   ├── news/
│   │   ├── data/          remote (Dio), local (Hive), models, NewsRepositoryImpl
│   │   ├── domain/        Article, NewsSource, NewsCategory, NewsRepository
│   │   └── presentation/  ArticlesCubit, SourcesCubit, pages, widgets
│   └── home/              HomeShell (navigation + bandeau de connectivité)
├── injection.dart     get_it
├── app.dart           thème + garde d'authentification
└── main.dart
server/                backend Dart (shelf)
```

### Stratégie de cache (NewsRepositoryImpl)

1. **En ligne** : appel API, puis la première page est enregistrée dans Hive
   sous une clé propre à la requête (`headlines_technology`, `search_flutter`,
   `source_bbc-news`, `sources_all`…).
2. **Hors-ligne, ou erreur serveur/réseau** : lecture du cache.
   `Success(fromCache: true, cachedAt: …)` fait apparaître le bandeau.
3. **Pas de cache** : `NetworkFailure` ou `ServerFailure`, et l'écran
   d'erreur propose « Réessayer ».
4. **401** : pas de repli sur le cache. L'intercepteur a déjà tenté le
   refresh ; si celui-ci a échoué, l'utilisateur est déconnecté.

### Flux du refresh token (AuthInterceptor)

`AuthInterceptor` étend `QueuedInterceptor` : si plusieurs requêtes
reçoivent un 401 en même temps, un seul refresh est fait et les suivantes
réutilisent le nouveau token.

1. `onRequest` : ajoute `Authorization: Bearer <access>`, sauf sur les routes
   marquées `skipAuth`.
2. `onError` sur un 401 : appelle `POST /auth/refresh` avec un client Dio
   séparé (sans intercepteur, donc sans boucle), enregistre les nouveaux
   tokens et rejoue la requête.
3. Refresh refusé (401) : efface les tokens et émet `sessionExpired`.
   `AuthCubit` revient alors à l'écran de connexion avec un message.
