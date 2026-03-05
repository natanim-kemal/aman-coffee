import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/number_formatter.dart';
import '../../widgets/stats_card.dart';
import '../../../core/services/report_service.dart';
import '../../widgets/custom_header.dart';
import '../../../l10n/app_localizations.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _dateFilter;
  String? _typeFilter;
  int _itemsToShow = 20; // Pagination - items per page
  static const int _itemsPerLoad = 20;
  DateTime? _selectedDate; // For "Choose Date" option
  
  late List<String> _dateOptions;
  late List<String> _typeOptions;

  // Cache for filtered transactions
  List<MoneyTransaction>? _cachedFilteredTransactions;
  int _lastTransactionCount = -1;
  String? _lastDateFilter;
  String? _lastTypeFilter;
  DateTime? _lastSelectedDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    
    _dateOptions = [
      l10n.today, 
      l10n.last7Days, 
      l10n.thisMonth, 
      l10n.allTime, 
      l10n.chooseDate
    ];
    
    _typeOptions = [
      l10n.all,
      l10n.distribute,
      l10n.returnMoney,
      l10n.coffeePurchase,
    ];

    // Ensure initial or valid selection
    if (_dateFilter == null || !_dateOptions.contains(_dateFilter)) {
      _dateFilter = l10n.last7Days;
    }
    
    if (_typeFilter == null || !_typeOptions.contains(_typeFilter)) {
      _typeFilter = l10n.all;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false).loadAllTransactions();
    });
  }
  
  void _loadMore() {
    setState(() {
      _itemsToShow += _itemsPerLoad;
    });
  }
  
  void _resetPagination() {
    setState(() {
      _itemsToShow = _itemsPerLoad;
    });
  }

  Future<void> _pickDate() async {
    final l10n = AppLocalizations.of(context)!;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).cardColor,
              onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateFilter = l10n.chooseDate;
        _itemsToShow = _itemsPerLoad; // Reset pagination
      });
    }
  }

  List<MoneyTransaction> _getFilteredTransactions(List<MoneyTransaction> allTransactions, AppLocalizations l10n) {
    DateTime now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;
    
    // Use localized strings for comparison
    if (_dateFilter == l10n.today) {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (_dateFilter == l10n.last7Days) {
      startDate = now.subtract(const Duration(days: 7));
    } else if (_dateFilter == l10n.thisMonth) {
      startDate = DateTime(now.year, now.month, 1);
    } else if (_dateFilter == l10n.allTime) {
      startDate = null;
    } else if (_dateFilter == l10n.chooseDate) {
      if (_selectedDate != null) {
        startDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
        endDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
      }
    }

    return allTransactions.where((t) {
      bool dateMatch;
      if (_dateFilter == l10n.chooseDate && startDate != null && endDate != null) {
        // For specific date, check if transaction is within that day
        dateMatch = t.createdAt.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                    t.createdAt.isBefore(endDate.add(const Duration(seconds: 1)));
      } else {
        dateMatch = startDate == null || t.createdAt.isAfter(startDate);
      }
      
      // Determine type match based on localized string mapping or internal type
      // Internal types: 'Distribution', 'Return', 'Purchase'
      bool typeMatch = false;
      String typeLower = t.type.toLowerCase();
      
      if (_typeFilter == l10n.all) {
        typeMatch = true;
      } else if (_typeFilter == l10n.distribute && typeLower == 'distribution') {
        typeMatch = true;
      } else if (_typeFilter == l10n.returnMoney && typeLower == 'return') {
        typeMatch = true;
      } else if (_typeFilter == l10n.coffeePurchase && typeLower == 'purchase') {
        typeMatch = true;
      }
      
      return dateMatch && typeMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    
    // Cache filtered transactions - only recalculate if filters or data changed
    final allTransactions = transactionProvider.allTransactions;
    if (_lastTransactionCount != allTransactions.length ||
        _lastDateFilter != _dateFilter ||
        _lastTypeFilter != _typeFilter ||
        _lastSelectedDate != _selectedDate) {
      _cachedFilteredTransactions = _getFilteredTransactions(allTransactions, l10n);
      _lastTransactionCount = allTransactions.length;
      _lastDateFilter = _dateFilter;
      _lastTypeFilter = _typeFilter;
      _lastSelectedDate = _selectedDate;
    }
    
    final filteredTransactions = _cachedFilteredTransactions ?? [];
    
    // Calculate summary
    double totalAmount = filteredTransactions.fold(0, (sum, t) => sum + t.amount);
    int count = filteredTransactions.length;


    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
          children: [
              // Header
              CustomHeader(
                height: 200, // Match WorkerListScreen header height
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.reports ?? 'Reports',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      IconButton(
                        onPressed: () async {
                           if (filteredTransactions.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppLocalizations.of(context)!.noDataToExport)),
                            );
                            return;
                          }
                          
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppLocalizations.of(context)!.preparingPdfReport)),
                            );

                            await ReportService().generateTransactionReport(
                              filteredTransactions,
                              _dateFilter!,
                              _typeFilter!,
                            );
                          } catch (e, stackTrace) {
                            print('Error generating PDF report: $e');
                            print(stackTrace);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${AppLocalizations.of(context)!.errorGeneratingReport}: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Filters matching Search Box style
                  Row(
                    children: [
                      Expanded(
                        child: _selectedDate != null 
                          ? _buildDateChip()
                          : _buildFilterDropdown(
                              value: _dateFilter!,
                              items: _dateOptions,
                              onChanged: (val) {
                                if (val == l10n.chooseDate) {
                                  _pickDate();
                                } else {
                                  setState(() {
                                    _dateFilter = val!;
                                    _selectedDate = null;
                                    _itemsToShow = _itemsPerLoad;
                                  });
                                }
                              },
                              icon: Icons.calendar_today,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFilterDropdown(
                          value: _typeFilter!,
                          items: _typeOptions,
                          onChanged: (val) => setState(() => _typeFilter = val!),
                          icon: Icons.filter_list,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Summary Cards
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  Provider.of<TransactionProvider>(context, listen: false).loadAllTransactions();
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                    // Quick Stats Row
                    _buildQuickStats(filteredTransactions),

                    const SizedBox(height: 24),

                    // Coffee Purchase Summary by Type
                    if (_typeFilter == l10n.all || _typeFilter == l10n.coffeePurchase)
                      _buildCoffeeSummary(filteredTransactions),

                    const SizedBox(height: 24),

                    // Transaction List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.transactions,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          '${filteredTransactions.length} ${AppLocalizations.of(context)!.records}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                    
                    if (filteredTransactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(context)!.noTransactionsFound,
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredTransactions.length > _itemsToShow 
                                ? _itemsToShow 
                                : filteredTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = filteredTransactions[index];
                              return _buildTransactionItem(transaction);
                            },
                          ),
                          // Load More button
                          if (filteredTransactions.length > _itemsToShow)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: OutlinedButton.icon(
                                onPressed: _loadMore,
                                icon: const Icon(Icons.expand_more),
                                label: Text(
                                  '${AppLocalizations.of(context)!.loadMore} (${filteredTransactions.length - _itemsToShow} ${AppLocalizations.of(context)!.remaining})',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            )
                          else if (filteredTransactions.length > _itemsPerLoad)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                AppLocalizations.of(context)!.showingAllTransactions(filteredTransactions.length),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                    const SizedBox(height: 80), 
                  ],
                ),
              ),
             ),
            ),
          ],
        ),
    );
  }

  Widget _buildDateChip() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                DateFormat('MMM d, yyyy').format(_selectedDate!),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = null;
                  _dateFilter = 'Last 7 Days'; // Keep default key for now to avoid breaking too much logic one shot
                  _itemsToShow = _itemsPerLoad;
                });
              },
              child: Icon(Icons.close, size: 18, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isDense: true,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                dropdownColor: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item, 
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(MoneyTransaction transaction) {
    Color getAmountColor() {
      switch (transaction.type.toLowerCase()) {
        case 'distribution': return Colors.green;
        case 'return': return Colors.red;
        case 'purchase': return Colors.orange;
        default: return Colors.black;
      }
    }

    IconData getIcon() {
      switch (transaction.type.toLowerCase()) {
        case 'distribution': return Icons.arrow_upward;
        case 'return': return Icons.arrow_downward;
        case 'purchase': return Icons.local_cafe;
        default: return Icons.article;
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              getIcon(),
              color: getAmountColor(),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.workerName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  DateFormat('MMM d, h:mm a').format(transaction.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${AppLocalizations.of(context)?.currency ?? 'ETB'} ${transaction.amount.formatted}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: getAmountColor(),
                ),
              ),
              Text(
                transaction.typeDisplay,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build quick stats row (top buyer, avg price, commission)
  Widget _buildQuickStats(List<MoneyTransaction> transactions) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Get purchase transactions only
    final purchases = transactions.where((t) => t.type.toLowerCase() == 'purchase').toList();
    
    // Calculate stats
    String topBuyer = '-';
    double avgPrice = 0;
    double totalCommission = 0;
    
    if (purchases.isNotEmpty) {
      // Find top buyer (by total amount)
      Map<String, double> buyerTotals = {};
      for (var t in purchases) {
        buyerTotals[t.workerName] = (buyerTotals[t.workerName] ?? 0) + t.amount;
      }
      topBuyer = buyerTotals.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      
      // Calculate average price per kg
      double totalWeight = 0;
      double totalValue = 0;
      for (var t in purchases) {
        if (t.coffeeWeight != null && t.coffeeWeight! > 0) {
          totalWeight += t.coffeeWeight!;
          totalValue += t.amount;
        }
      }
      if (totalWeight > 0) {
        avgPrice = totalValue / totalWeight;
      }
      
      // Calculate total commission
      for (var t in purchases) {
        totalCommission += t.commissionAmount ?? 0;
      }
    }
    
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.emoji_events,
            label: 'Top Buyer',
            value: topBuyer.length > 10 ? '${topBuyer.substring(0, 10)}...' : topBuyer,
            color: Colors.amber,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.trending_up,
            label: 'Avg Price',
            value: 'ETB ${avgPrice.formatted}/Kg',
            color: Colors.purple,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.paid,
            label: 'Commission',
            value: 'ETB ${totalCommission.formatted}',
            color: Colors.teal,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build coffee purchase summary by type
  Widget _buildCoffeeSummary(List<MoneyTransaction> transactions) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Get purchase transactions only
    final purchases = transactions.where((t) => t.type.toLowerCase() == 'purchase').toList();
    
    if (purchases.isEmpty) return const SizedBox.shrink();
    
    // Group by coffee type
    Map<String, Map<String, double>> coffeeData = {};
    
    for (var t in purchases) {
      String type = t.coffeeType ?? 'Unknown';
      type = type.isNotEmpty ? type[0].toUpperCase() + type.substring(1) : 'Unknown';
      
      coffeeData.putIfAbsent(type, () => {'qty': 0, 'total': 0, 'count': 0});
      coffeeData[type]!['qty'] = (coffeeData[type]!['qty'] ?? 0) + (t.coffeeWeight ?? 0);
      coffeeData[type]!['total'] = (coffeeData[type]!['total'] ?? 0) + t.amount;
      coffeeData[type]!['count'] = (coffeeData[type]!['count'] ?? 0) + 1;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_cafe, color: Colors.brown, size: 20),
              const SizedBox(width: 8),
              Text(
                'Coffee Purchases by Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Header
          Row(
            children: [
              Expanded(flex: 2, child: Text('Type', style: _headerStyle(isDark))),
              Expanded(flex: 1, child: Text('Qty', style: _headerStyle(isDark), textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('Avg Price', style: _headerStyle(isDark), textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('Total', style: _headerStyle(isDark), textAlign: TextAlign.right)),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          const SizedBox(height: 8),
          
          // Data rows
          ...coffeeData.entries.map((entry) {
            final type = entry.key;
            final data = entry.value;
            final qty = data['qty'] ?? 0;
            final total = data['total'] ?? 0;
            final avgPrice = qty > 0 ? total / qty : 0;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2, 
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getCoffeeTypeColor(type),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(type, style: _valueStyle(isDark)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1, 
                    child: Text(
                      '${qty.formatted} Kg',
                      style: _valueStyle(isDark),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2, 
                    child: Text(
                      'ETB ${avgPrice.formatted}',
                      style: _valueStyle(isDark),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2, 
                    child: Text(
                      'ETB ${total.formatted}',
                      style: _valueStyle(isDark).copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  TextStyle _headerStyle(bool isDark) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
    );
  }

  TextStyle _valueStyle(bool isDark) {
    return TextStyle(
      fontSize: 13,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  Color _getCoffeeTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'jenfel':
        return Colors.brown;
      case 'yetatebe':
        return Colors.orange;
      case 'special':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
