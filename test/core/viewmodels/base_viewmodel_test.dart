import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/features/core/viewmodels/base_viewmodel.dart';

class MockModel {
  final int id;
  final String name;

  MockModel({required this.id, required this.name});
}

class TestViewModel extends BaseViewModel<MockModel> {}

void main() {
  group('BaseViewModel', () {
    late TestViewModel viewModel;

    setUp(() {
      viewModel = TestViewModel();
    });

    test('initial state is idle', () {
      expect(viewModel.state, 'idle');
      expect(viewModel.isLoading, false);
    });

    test('setLoading sets state to loading', () {
      viewModel.setLoading();
      expect(viewModel.state, 'loading');
      expect(viewModel.isLoading, true);
    });

    test('setSuccess sets state to success', () {
      viewModel.setSuccess();
      expect(viewModel.state, 'success');
    });

    test('setError sets state to error and message', () {
      const errorMsg = 'Test error';
      viewModel.setError(errorMsg);
      expect(viewModel.state, 'error');
      expect(viewModel.errorMessage, errorMsg);
    });

    test('setItems adds items to list', () {
      final items = [
        MockModel(id: 1, name: 'Item 1'),
        MockModel(id: 2, name: 'Item 2'),
      ];
      viewModel.setItems(items);
      expect(viewModel.items.length, 2);
      expect(viewModel.items[0].name, 'Item 1');
    });

    test('notifies listeners on state change', () {
      var notificationCount = 0;
      viewModel.addListener(() {
        notificationCount++;
      });

      viewModel.setLoading();
      expect(notificationCount, 1);

      viewModel.setSuccess();
      expect(notificationCount, 2);
    });

    test('items getter returns empty list initially', () {
      expect(viewModel.items, []);
    });

    test('setItems clears previous items', () {
      viewModel.setItems([MockModel(id: 1, name: 'First')]);
      expect(viewModel.items.length, 1);

      viewModel.setItems([MockModel(id: 2, name: 'Second')]);
      expect(viewModel.items.length, 1);
      expect(viewModel.items[0].name, 'Second');
    });
  });
}
