import 'dart:developer' as dev show log;
import 'dart:math' as math;

extension Log on Object {
  void log() => dev.log(toString());
}

extension EmptyOnError<E> on Future<List<Iterable<E>>> {
  Future<List<Iterable<E>>> emptyOnError() =>
      catchError((_, __) => List<Iterable<E>>.empty());
}

extension EmptyOnErrorOnFuture<E> on Future<Iterable<E>> {
  Future<Iterable<E>> emptyOnErrorOnFuture() =>
      catchError((_, __) => Iterable<E>.empty());
}

extension RandomElement<T> on Iterable<T> {
  T getRandomElement() => elementAt(math.Random().nextInt(length));
}
