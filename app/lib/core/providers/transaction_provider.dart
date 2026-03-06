import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

class TransactionProvider with ChangeNotifier {
  final TransactionService _transactionService = TransactionService();

  List<MoneyTransaction> _allTransactions = [];
  List<MoneyTransaction> _workerTransactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Today's totals
  double _todayDistributed = 0.0;
  double _todayReturned = 0.0;
  double _todayPurchased = 0.0;

  // Cached chart data for dashboard
  Map<String, List<double>>? _last7DaysCache;
  DateTime? _cacheTimestamp;

  List<MoneyTransaction> get allTransactions => _allTransactions;
  List<MoneyTransaction> get workerTransactions => _workerTransactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get todayDistributed => _todayDistributed;
  double get todayReturned => _todayReturned;
  double get todayPurchased => _todayPurchased;
  double get todayNet => _todayDistributed - _todayReturned - _todayPurchased;

  /// Get cached chart data for last 7 days
  Map<String, List<double>> getLast7DaysChartData() {
    // Return cached data if it's less than 5 minutes old
    if (_last7DaysCache != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!) < const Duration(minutes: 5)) {
      return _last7DaysCache!;
    }
    
    // Recalculate and cache
    _last7DaysCache = _calculateLast7DaysData();
    _cacheTimestamp = DateTime.now();
    return _last7DaysCache!;
  }

  /// Calculate chart data for last 7 days (optimized with O(1) lookups)
  Map<String, List<double>> _calculateLast7DaysData() {
    final now = DateTime.now();
    final distributionData = List<double>.filled(7, 0.0);
    final returnData = List<double>.filled(7, 0.0);
    
    // Pre-calculate day boundaries and create a map for O(1) lookups
    final dayToIndexMap = <DateTime, int>{};
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: 6 - i));
      final dayBoundary = DateTime(day.year, day.month, day.day);
      dayToIndexMap[dayBoundary] = i;
    }
    
    // Single pass through transactions with O(1) day lookup
    for (final transaction in _allTransactions) {
      final transactionDay = DateTime(
        transaction.createdAt.year,
        transaction.createdAt.month,
        transaction.createdAt.day,
      );
      
      // O(1) lookup to find the day index
      final index = dayToIndexMap[transactionDay];
      if (index != null) {
        if (transaction.type == 'distribution') {
          distributionData[index] += transaction.amount;
        } else if (transaction.type == 'return') {
          returnData[index] += transaction.amount;
        }
      }
    }
    
    return {
      'distribution': distributionData,
      'return': returnData,
    };
  }

  /// Invalidate cache when transactions change
  void _invalidateCache() {
    _last7DaysCache = null;
    _cacheTimestamp = null;
  }

  /// Load worker transactions
  void loadWorkerTransactions(String workerId) {
    _transactionService.getWorkerTransactionsStream(workerId).listen(
      (transactions) {
        _workerTransactions = transactions;
        notifyListeners();
      },
      onError: (error) {
        print('Error loading worker transactions: $error');
        _errorMessage = _parseError(error);
        notifyListeners();
      },
    );
  }

  /// Load all transactions
  void loadAllTransactions() {
    _transactionService.getAllTransactionsStream().listen(
      (transactions) {
        _allTransactions = transactions;
        _invalidateCache(); // Invalidate cache when transactions change
        notifyListeners();
      },
      onError: (error) {
        print('Error loading all transactions: $error');
        _errorMessage = _parseError(error);
        notifyListeners();
      },
    );
  }

  /// Get all transactions as a Future (for export)
  Future<List<MoneyTransaction>> getAllTransactionsFuture() async {
    return await _transactionService.getAllTransactions();
  }

  /// Add distribution transaction
  Future<bool> distributeMoneyToWorker({
    required String workerId,
    required String workerName,
    required double amount,
    required String createdBy,
    String? notes,
    String? receiptUrl,
  }) async {
    if (amount <= 0) {
      _errorMessage = 'Amount must be greater than 0';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final transaction = MoneyTransaction(
        id: '',
        workerId: workerId,
        workerName: workerName,
        type: 'distribution',
        amount: amount,
        notes: notes,
        receiptUrl: receiptUrl,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );

      await _transactionService.addTransaction(transaction);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Add return transaction
  Future<bool> returnMoneyFromWorker({
    required String workerId,
    required String workerName,
    required double amount,
    required String createdBy,
    String? notes,
    String? receiptUrl,
  }) async {
    if (amount <= 0) {
      _errorMessage = 'Amount must be greater than 0';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final transaction = MoneyTransaction(
        id: '',
        workerId: workerId,
        workerName: workerName,
        type: 'return',
        amount: amount,
        notes: notes,
        receiptUrl: receiptUrl,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );

      await _transactionService.addTransaction(transaction);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Add purchase transaction
  Future<bool> recordCoffeePurchase({
    required String workerId,
    required String workerName,
    required double amount,
    required String createdBy,
    String? notes,
    String? receiptUrl,
    String? coffeeType,
    double? weight,
    double? pricePerKg,
    double? commission,
  }) async {
    if (amount <= 0) {
      _errorMessage = 'Amount must be greater than 0';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final transaction = MoneyTransaction(
        id: '',
        workerId: workerId,
        workerName: workerName,
        type: 'purchase',
        amount: amount,
        notes: notes,
        receiptUrl: receiptUrl,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        coffeeType: coffeeType,
        coffeeWeight: weight,
        pricePerKg: pricePerKg,
        commissionAmount: commission,
      );

      await _transactionService.addTransaction(transaction);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load today's totals
  Future<void> loadTodayTotals() async {
    try {
      final totals = await _transactionService.getTodayTotals();
      _todayDistributed = totals['distributed'] ?? 0.0;
      _todayReturned = totals['returned'] ?? 0.0;
      _todayPurchased = totals['purchased'] ?? 0.0;
      notifyListeners();
    } catch (e) {
      print('Error loading today totals: $e');
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Parse error message
  String _parseError(dynamic error) {
    String errorStr = error.toString();
    if (errorStr.contains('permission-denied') || 
        errorStr.contains('PERMISSION_DENIED')) {
      return 'Database access denied. Please check permissions.';
    } else if (errorStr.contains('unavailable')) {
      return 'Database unavailable. Check your connection.';
    }
    return 'Failed to load transactions.';
  }

  /// Upload receipt
  Future<String?> uploadReceipt(String filePath) async {
    try {
      _isLoading = true;
      notifyListeners();
      final url = await _transactionService.uploadReceipt(filePath);
      _isLoading = false;
      notifyListeners();
      return url;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
