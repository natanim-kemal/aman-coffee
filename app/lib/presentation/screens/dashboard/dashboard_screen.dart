import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/worker_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../main.dart';
import '../../dialogs/ping_dialog.dart';
import '../../widgets/stats_card.dart';
import '../../widgets/activity_chart.dart';
import '../../widgets/worker_item.dart';
import '../../widgets/notification_badge.dart';
import '../notifications/notifications_screen.dart';
import '../worker_detail/worker_detail_screen.dart';
import '../../widgets/custom_header.dart';
import '../../../l10n/app_localizations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Cache for expensive computations
  List<double>? _cachedDistributedData;
  List<double>? _cachedReturnedData;
  List<String>? _cachedLabels;
  List<dynamic>? _cachedActiveWorkers;
  int _lastTransactionCount = -1;
  int _lastWorkerCount = -1;
  int _lastLabelDay = -1; // Track current day for label caching

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
      transactionProvider.loadTodayTotals();
      transactionProvider.loadAllTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final workerProvider = Provider.of<WorkerProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Robust Localization: Allow null, use fallbacks
    final AppLocalizations? localizations = AppLocalizations.of(context);

    // Cache expensive computations - only recalculate if data changed
    if (_lastTransactionCount != transactionProvider.allTransactions.length) {
      _cachedDistributedData = _getLast7DaysData('distribution', transactionProvider.allTransactions);
      _cachedReturnedData = _getLast7DaysData('return', transactionProvider.allTransactions);
      _lastTransactionCount = transactionProvider.allTransactions.length;
    }

    // Cache labels separately - only recalculate when day changes
    final currentDay = DateTime.now().day;
    if (_lastLabelDay != currentDay) {
      _cachedLabels = _getLast7DaysLabels();
      _lastLabelDay = currentDay;
    }

    if (_lastWorkerCount != workerProvider.workers.length) {
      _cachedActiveWorkers = workerProvider.workers
          .where((w) => w.status == 'active')
          .take(3)
          .toList();
      _lastWorkerCount = workerProvider.workers.length;
    }

    final distributedData = _cachedDistributedData ?? [];
    final returnedData = _cachedReturnedData ?? [];
    final labels = _cachedLabels ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await workerProvider.refresh();
          await transactionProvider.loadTodayTotals();
          transactionProvider.loadAllTransactions();
        },
        child: Column(
          children: [
             CustomHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations?.welcomeBack ?? 'Welcome Back,',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                             authProvider.user?.displayName ?? 'User',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Admin Ping All Button
                          if (authProvider.isAdmin)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.campaign, color: Colors.white),
                                tooltip: localizations?.pingAllWorkers ?? 'Ping All Workers',
                                onPressed: () => _showPingAllDialog(context, authProvider),
                              ),
                            ),
                          NotificationBadge(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const NotificationsScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Compact Stats (Moved Up)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCompactStat(context, Icons.people, '${workerProvider.totalWorkers}', localizations?.total ?? 'Total', AppColors.primary),
                          _buildContainerDivider(isDark),
                          _buildCompactStat(context, Icons.check_circle, '${workerProvider.activeToday}', localizations?.active ?? 'Active', AppColors.primary),
                          _buildContainerDivider(isDark),
                          _buildCompactStat(context, Icons.star, '${workerProvider.avgPerformance.toStringAsFixed(0)}%', localizations?.perf ?? 'Perf', AppColors.primary),
                          _buildContainerDivider(isDark),
                          _buildCompactStat(context, Icons.local_cafe, '${transactionProvider.todayPurchased.formatted}', localizations?.sales ?? 'Sales', AppColors.primary),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Today's Overview Card (Moved Down)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                localizations?.todaysActivity ?? "Today's Activity",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTodayStatItem(
                                  localizations?.distributed ?? 'Distributed',
                                  '${localizations?.currency ?? "ETB"} ${transactionProvider.todayDistributed.formatted}',
                                  Icons.arrow_downward,
                                  Colors.white,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: Colors.white24,
                              ),
                              Expanded(
                                child: _buildTodayStatItem(
                                  localizations?.returned ?? 'Returned',
                                  '${localizations?.currency ?? "ETB"} ${transactionProvider.todayReturned.formatted}',
                                  Icons.arrow_upward,
                                  Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Colors.white24),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                localizations?.netBalance ?? 'Net Balance',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${localizations?.currency ?? "ETB"} ${transactionProvider.todayNet.formatted}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Activity Chart
                    ActivityChart(
                      distributedData: distributedData,
                      returnedData: returnedData,
                      labels: labels,
                    ),

                    const SizedBox(height: 24),

                    // Active Workers Section
                    if (workerProvider.workers.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            localizations?.activeWorkers ?? 'Active Workers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              MainLayout.navigateTo(1); 
                            },
                            child: Text(
                              localizations?.viewAll ?? 'View All',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...(_cachedActiveWorkers ?? [])
                          .map((worker) {
                            final isLowBalance = worker.currentBalance < 500;
                            final balanceColor = isLowBalance ? Colors.red : Colors.green;
                            
                            return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            WorkerDetailScreen(workerId: worker.id),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary.withOpacity(0.1),
                                        ),
                                        child: Center(
                                          child: Text(
                                            worker.name.substring(0, 2).toUpperCase(),
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              worker.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              worker.role,
                                              style: TextStyle(
                                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Balance Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: balanceColor.withOpacity(isDark ? 0.2 : 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'ETB ${worker.currentBalance.formatted}',
                                              style: TextStyle(
                                                color: balanceColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (isLowBalance)
                                              Text(
                                                'Low',
                                                style: TextStyle(
                                                  color: balanceColor,
                                                  fontSize: 10,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                          }),
                    ] else ...[
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.people_outline,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              localizations?.noWorkersYet ?? 'No workers yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              localizations?.addWorkersToGetStarted ?? 'Add workers to get started',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _getLast7DaysData(String type, List<dynamic> transactions) {
    final now = DateTime.now();
    // Initialize 7 days of data
    List<double> data = List.filled(7, 0.0);
    
    // Single pass through all transactions
    for (var t in transactions) {
      if (t.type != type) continue;
      
      final transactionDate = t.createdAt;
      final daysDifference = now.difference(transactionDate).inDays;
      
      // Check if transaction is within the last 7 days
      if (daysDifference >= 0 && daysDifference < 7) {
        // Calculate index (6 = today, 0 = 6 days ago)
        final index = 6 - daysDifference;
        
        // Verify it's the same calendar day using normalized date comparison
        final normalizedNow = DateTime(now.year, now.month, now.day);
        final normalizedTransaction = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);
        final normalizedTarget = normalizedNow.subtract(Duration(days: daysDifference));
        
        if (normalizedTransaction.isAtSameMomentAs(normalizedTarget)) {
          data[index] += t.amount;
        }
      }
    }
    
    return data;
  }

  List<String> _getLast7DaysLabels() {
    final now = DateTime.now();
    List<String> labels = [];
    
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      labels.add(DateFormat('E').format(day));
    }
    return labels;
  }

  Widget _buildTodayStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStat(BuildContext context, IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Future<void> _showPingAllDialog(BuildContext context, AuthProvider authProvider) async {
    final localizations = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder: (context) => PingDialog(
        title: localizations?.pingAllWorkers ?? 'Ping All Workers',
        messageLabel: localizations?.messageToAllWorkers ?? 'Message to all workers',
        onSend: (message) async {
          final notificationProvider =
              Provider.of<NotificationProvider>(context, listen: false);
          
          await notificationProvider.sendGlobalPing(
            title: localizations?.announcement ?? 'Announcement',
            body: message,
            senderName: authProvider.user?.displayName ?? localizations?.admin ?? 'Admin',
            senderId: authProvider.user?.uid ?? '',
          );
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations?.notificationSentToAll ?? 'Notification sent to all workers')),
            );
          }
        },
      ),
    );
  }

  Widget _buildContainerDivider(bool isDark) {
    return Container(
      width: 1,
      height: 40,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
    );
  }
}
