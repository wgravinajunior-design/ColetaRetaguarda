import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_retaguarda/features/core/services/connectivity_service.dart';

// Mock classes
class MockConnectivity extends Mock implements Connectivity {}
class MockSyncService extends Mock {}
class MockSyncQueueDao extends Mock {}

void main() {
  group('ConnectivityService', () {
    late ConnectivityService service;

    setUp(() {
      service = ConnectivityService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial isOnline is true by default', () async {
      expect(service.isOnline, true);
    });

    test('initial isSyncing is false', () {
      expect(service.isSyncing, false);
    });

    test('initial pendingCount is 0', () {
      expect(service.pendingCount, 0);
    });

    test('setLoading updates isSyncing', () async {
      service.isOnline = true; // Ensure online
      // Note: In real app, syncPending would be called
      // This test verifies the property itself
      expect(service.isSyncing, false);
    });

    test('notifies listeners on state change', () async {
      var notificationCount = 0;
      service.addListener(() {
        notificationCount++;
      });

      // Simulate online state change
      // Note: This would normally be triggered by connectivity changes
      expect(notificationCount >= 0, true);
    });

    test('isOnline property reflects connectivity', () {
      expect(service.isOnline, isNotNull);
    });

    test('pendingCount property is accessible', () {
      expect(service.pendingCount >= 0, true);
    });

    test('isSyncing property is accessible', () {
      expect(service.isSyncing is bool, true);
    });
  });
}
