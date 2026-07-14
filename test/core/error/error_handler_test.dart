import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/error/error_handler.dart';

void main() {
  group('ErrorHandler', () {
    late ErrorHandler errorHandler;

    setUp(() {
      errorHandler = ErrorHandler();
    });

    test('is singleton', () {
      final handler1 = ErrorHandler();
      final handler2 = ErrorHandler();

      expect(identical(handler1, handler2), true);
    });

    test('sets context', () {
      final handler = ErrorHandler();
      final mockContext = _MockBuildContext();

      // Context should be settable without error
      expect(() {
        handler.setContext(mockContext);
      }, returnsNormally);
    });

  });
}

class _MockBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
