import '../error/failures.dart';

/// Résultat d'une opération de repository : soit une donnée, soit un [Failure].
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(Success<T> success) success,
    required R Function(Failure failure) failure,
  }) => switch (this) {
    final Success<T> s => success(s),
    ResultFailure<T>(failure: final f) => failure(f),
  };
}

class Success<T> extends Result<T> {
  const Success(this.data, {this.fromCache = false, this.cachedAt});

  final T data;

  /// `true` si la donnée provient du cache local (mode hors-ligne).
  final bool fromCache;

  /// Date de mise en cache, renseignée quand [fromCache] est vrai.
  final DateTime? cachedAt;
}

class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);
  final Failure failure;
}
