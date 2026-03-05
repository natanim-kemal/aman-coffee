# Performance Optimization Testing Guide

This guide provides detailed instructions for testing the performance improvements made to the Aman Coffee application.

## Overview

The performance optimizations target three main areas:
1. **Dashboard Screen** - Chart rendering and widget rebuild optimizations
2. **Reports Screen** - Transaction filtering and caching
3. **Firebase Functions** - Push notification delivery and cleanup operations

## Prerequisites

- Access to the Aman Coffee app with admin credentials
- Test dataset with 100+ transactions across multiple days
- Firebase Console access for monitoring functions
- Device or emulator for testing Flutter app
- Network monitoring tools (optional but recommended)

## Test Plan

### 1. Dashboard Screen Performance Tests

#### Test 1.1: Chart Data Rendering
**Objective:** Verify chart renders efficiently with optimized algorithm

**Steps:**
1. Clear app cache/data to start fresh
2. Login to the app
3. Navigate to Dashboard
4. Observe initial chart rendering time
5. Pull to refresh and observe rendering time
6. Scroll to trigger rebuilds

**Expected Results:**
- Initial chart renders in < 200ms (previously ~1-2s with 1000+ transactions)
- No visible lag during pull-to-refresh
- Smooth scrolling with no jank
- Chart data updates correctly after refresh

**Verification:**
```dart
// Enable performance overlay in Flutter
flutter run --profile
// Or add in main.dart:
MaterialApp(
  showPerformanceOverlay: true,
  ...
)
```

#### Test 1.2: Cache Invalidation
**Objective:** Verify cached data updates when underlying data changes

**Steps:**
1. View dashboard with existing transactions
2. Add a new transaction (distribution or return)
3. Return to dashboard
4. Verify chart updates with new data
5. Add another transaction the next day
6. Verify chart labels update (if day changed)

**Expected Results:**
- Chart data updates immediately after new transaction
- Labels update only when day changes
- No stale data displayed
- Active workers list updates when worker status changes

#### Test 1.3: Provider Rebuild Prevention
**Objective:** Verify dashboard doesn't rebuild on unrelated state changes

**Steps:**
1. Open dashboard
2. Trigger auth provider change (e.g., update user profile)
3. Observe if dashboard rebuilds unnecessarily
4. Monitor rebuild count in Flutter DevTools

**Expected Results:**
- Dashboard does NOT rebuild on auth provider changes
- Only rebuilds when transaction or worker data changes
- Reduced rebuild count by ~70-80% compared to before

**Monitoring:**
```dart
// Add to DashboardScreen build method temporarily:
@override
Widget build(BuildContext context) {
  print('Dashboard rebuild: ${DateTime.now()}');
  ...
}
```

### 2. Reports Screen Performance Tests

#### Test 2.1: Filter Performance
**Objective:** Verify filtering is instant with cached results

**Steps:**
1. Navigate to Reports screen
2. Apply different date filters rapidly:
   - Today
   - Last 7 Days
   - This Month
   - All Time
3. Apply different type filters:
   - All
   - Distribution
   - Return
   - Purchase
4. Combine filters (e.g., Last 7 Days + Distribution)

**Expected Results:**
- Filter changes are instant (< 50ms)
- No lag or stutter when changing filters
- Results are accurate for each filter combination
- Summary calculations update correctly

**Performance Measurement:**
```dart
// Add timing in _getFilteredTransactions:
final stopwatch = Stopwatch()..start();
final result = _getFilteredTransactions(...);
stopwatch.stop();
print('Filter time: ${stopwatch.elapsedMilliseconds}ms');
```

#### Test 2.2: Cache Invalidation
**Objective:** Verify cache updates when filters or data change

**Steps:**
1. Apply a filter (e.g., Last 7 Days)
2. Add a new transaction
3. Verify filtered results include new transaction
4. Change filter
5. Verify results reflect new filter immediately

**Expected Results:**
- Cache invalidates correctly on data changes
- New transactions appear in filtered results
- No duplicate calculations for same filter
- Pagination works correctly with cached data

#### Test 2.3: Large Dataset Handling
**Objective:** Test performance with large transaction counts

**Steps:**
1. Import test data with 500+ transactions
2. Navigate to Reports screen
3. Apply various filters
4. Scroll through paginated results
5. Export data

**Expected Results:**
- Initial load completes in < 500ms
- Filter changes remain instant
- Smooth scrolling through results
- Export completes without timeout

### 3. Firebase Functions Performance Tests

#### Test 3.1: Push Notification Delivery
**Objective:** Verify notifications send efficiently with batched writes

**Steps:**
1. Create a test notification via Firebase Console or app
2. Monitor function execution time in Firebase Console
3. Verify notification appears on target device
4. Check Firestore for updated notification document
5. Verify batch write completed successfully

**Expected Results:**
- Function execution time < 2s (previously ~3-5s)
- Single batch write instead of multiple writes
- Notification marked as `pushSent: true`
- No write failures or timeouts

**Monitoring:**
```bash
# View function logs
firebase functions:log --only sendPushNotification

# Expected log output:
# "Push notification sent successfully"
# "Batch write completed"
```

#### Test 3.2: Invalid Token Handling
**Objective:** Verify error handling with batched cleanup

**Steps:**
1. Manually create user with invalid FCM token in Firestore
2. Send notification to that user
3. Verify function handles error gracefully
4. Check that invalid token is removed
5. Verify notification marked with error

**Expected Results:**
- Function doesn't crash on invalid token
- Token removed from user document in single batch
- Notification marked as failed with error message
- Error logged clearly in Cloud Functions logs

#### Test 3.3: Notification Cleanup
**Objective:** Verify cleanup function uses correct timestamp format

**Steps:**
1. Create test notifications with old timestamps (31+ days ago)
2. Trigger cleanup function manually or wait for scheduled run
3. Verify old notifications deleted
4. Check for composite index warnings

**Expected Results:**
- Old notifications deleted successfully
- No timestamp comparison errors
- Batch size limited to 500 per run
- Function completes in < 10s
- Proper index used (no warnings)

**Manual Trigger:**
```bash
# Test cleanup function locally
firebase functions:shell
# Then run:
cleanupOldNotifications({})
```

#### Test 3.4: Timeout Handling
**Objective:** Verify messaging timeout protection

**Steps:**
1. Simulate network delay (if possible)
2. Send notification with delayed network
3. Verify function times out after 10 seconds
4. Check error handling

**Expected Results:**
- Function times out gracefully after 10s
- Error logged with "messaging-timeout"
- No hung functions in Firebase Console
- Proper cleanup on timeout

### 4. Regression Tests

#### Test 4.1: Existing Functionality
**Objective:** Verify no breaking changes to existing features

**Steps:**
1. Test all dashboard features:
   - View stats cards
   - Click on active workers
   - View transaction history
   - Pull to refresh
2. Test all reports features:
   - Export data
   - Pagination
   - Date picker
3. Test notifications:
   - Receive notifications
   - View notification list
   - Mark as read

**Expected Results:**
- All features work as before
- No crashes or errors
- UI remains responsive
- Data accuracy maintained

#### Test 4.2: Edge Cases
**Objective:** Test boundary conditions

**Test Cases:**
- Empty transaction list
- Single transaction
- 10,000+ transactions
- Transactions exactly at midnight
- Notifications with very long text
- Network offline scenarios
- App backgrounding during operations

**Expected Results:**
- Graceful handling of all edge cases
- No crashes or infinite loops
- Proper error messages
- Cache invalidation works correctly

## Performance Metrics

### Key Performance Indicators (KPIs)

| Metric | Before | Target | How to Measure |
|--------|--------|--------|----------------|
| Dashboard chart render time | ~1-2s | < 200ms | Flutter DevTools Timeline |
| Dashboard rebuild frequency | High | 70-80% reduction | Build counter in code |
| Reports filter change time | ~300-500ms | < 50ms | Stopwatch in code |
| Firebase function execution | ~3-5s | < 2s | Firebase Console Metrics |
| Firebase write operations | 2-4 per notification | 1 batch | Firestore Usage Dashboard |

### Monitoring Tools

1. **Flutter DevTools**
   - Performance tab for rebuild tracking
   - Timeline for operation profiling
   - Memory tab for leak detection

2. **Firebase Console**
   - Functions execution time
   - Error rates
   - Firestore read/write counts

3. **App-level Logging**
   ```dart
   // Add performance markers
   Timeline.startSync('chart_calculation');
   // ... operation ...
   Timeline.finishSync();
   ```

## Automated Testing

### Unit Tests (Recommended Additions)

```dart
// test/dashboard_screen_test.dart
void main() {
  test('_getLast7DaysData returns correct data structure', () {
    final state = _DashboardScreenState();
    final transactions = createTestTransactions();
    final result = state._getLast7DaysData('distribution', transactions);
    
    expect(result.length, 7);
    expect(result[0], isA<double>());
  });

  test('Cache invalidation works correctly', () {
    // Test cache updates on data change
    // Test cache retention when data unchanged
  });
}

// test/reports_screen_test.dart
void main() {
  test('Filter cache invalidates on filter change', () {
    // Test cache behavior
  });
}
```

### Integration Tests

```dart
// integration_test/performance_test.dart
void main() {
  testWidgets('Dashboard loads within acceptable time', (tester) async {
    final stopwatch = Stopwatch()..start();
    
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();
    
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });
}
```

## Troubleshooting

### Common Issues

1. **Cache not invalidating**
   - Check comparison logic in build methods
   - Verify tracking variables initialized correctly
   - Ensure data changes trigger state updates

2. **Firebase function timeouts**
   - Check network connectivity
   - Verify timeout constant set correctly
   - Review function logs for errors

3. **Incorrect chart data**
   - Verify date normalization logic
   - Check transaction type filtering
   - Confirm timezone handling

### Debug Mode

Enable verbose logging:
```dart
// In dashboard_screen.dart
if (_lastTransactionCount != transactionProvider.allTransactions.length) {
  print('Cache miss: transaction count changed from $_lastTransactionCount to ${transactionProvider.allTransactions.length}');
  // ...
}
```

## Success Criteria

The performance optimization is considered successful if:

- ✅ Dashboard renders in < 200ms with 1000+ transactions
- ✅ Chart data calculation uses single-pass algorithm (O(n))
- ✅ Dashboard rebuilds reduced by 70%+ 
- ✅ Reports filter changes complete in < 50ms
- ✅ Firebase function execution time < 2s
- ✅ Write operations reduced from 2-4 to 1 batch
- ✅ No regression in existing functionality
- ✅ No new security vulnerabilities (CodeQL clean)
- ✅ All edge cases handled gracefully

## Conclusion

Following this test plan ensures all performance optimizations work correctly and deliver the expected improvements without breaking existing functionality. Report any issues or unexpected behavior to the development team.
