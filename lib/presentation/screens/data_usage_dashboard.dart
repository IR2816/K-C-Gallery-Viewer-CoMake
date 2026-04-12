import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/data_usage_tracker.dart';
import 'package:intl/intl.dart';

/// Data Usage Dashboard Screen
class DataUsageDashboard extends StatefulWidget {
  const DataUsageDashboard({super.key});

  @override
  State<DataUsageDashboard> createState() => _DataUsageDashboardState();
}

class _DataUsageDashboardState extends State<DataUsageDashboard> {
  static const double _minThresholdGap = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Data Usage Monitor'),
        backgroundColor: AppTheme.getSurfaceColor(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.getOnSurfaceColor(context)),
      ),
      body: Consumer<DataUsageTracker>(
        builder: (context, tracker, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentSessionCard(tracker),
                const SizedBox(height: 16),
                _buildTodayUsageCard(tracker),
                const SizedBox(height: 16),
                _buildCategoryBreakdownCard(tracker),
                const SizedBox(height: 16),
                _buildLimitsCard(tracker),
                const SizedBox(height: 16),
                _buildPeriodSummaryCard(tracker),
                const SizedBox(height: 16),
                _buildUsageHistoryCard(tracker),
                const SizedBox(height: 16),
                _buildTrackedSourcesCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentSessionCard(DataUsageTracker tracker) {
    final sessionUsageMB = tracker.getUsageInMB(tracker.sessionUsage);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.data_usage,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Current Session',
                style: AppTheme.subtitleStyle.copyWith(
                  color: AppTheme.getOnSurfaceColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${sessionUsageMB.toStringAsFixed(2)} MB',
                    style: AppTheme.heading2Style.copyWith(
                      color: AppTheme.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Data used',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SessionClock(sessionStart: tracker.sessionStart),
                  Text(
                    'Session duration',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayUsageCard(DataUsageTracker tracker) {
    final todayUsage = tracker.todayUsage;
    final dailyLimitMB = tracker.limits.dailyLimitMB;

    if (todayUsage == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: Text(
            'No usage data for today',
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    final usageMB = tracker.getUsageInMB(todayUsage.totalUsage);
    final percentage = (usageMB / dailyLimitMB) * 100;
    final remainingMB = dailyLimitMB - usageMB;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getUsageColor(percentage).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.today,
                  color: _getUsageColor(percentage),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Today's Usage",
                  style: AppTheme.subtitleStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: AppTheme.bodyStyle.copyWith(
                  color: _getUsageColor(percentage),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percentage / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _getUsageColor(percentage),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${usageMB.toStringAsFixed(2)} MB',
                    style: AppTheme.heading2Style.copyWith(
                      color: AppTheme.getOnSurfaceColor(context),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Used today',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${remainingMB.toStringAsFixed(1)} MB',
                    style: AppTheme.bodyStyle.copyWith(
                      color: remainingMB > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    remainingMB > 0 ? 'Remaining' : 'Over limit',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(DataUsageTracker tracker) {
    final categoryUsage = tracker.sessionCategoryUsage;
    final totalUsage = tracker.sessionUsage;

    if (totalUsage == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.pie_chart,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Category Breakdown',
                style: AppTheme.subtitleStyle.copyWith(
                  color: AppTheme.getOnSurfaceColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...categoryUsage.entries.map((entry) {
            final category = entry.key;
            final bytes = entry.value;
            final percentage = totalUsage > 0
                ? (bytes / totalUsage) * 100
                : 0.0;
            final usageMB = tracker.getUsageInMB(bytes);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getCategoryName(category),
                      style: AppTheme.bodyStyle.copyWith(
                        color: AppTheme.getOnSurfaceColor(context),
                      ),
                    ),
                  ),
                  Text(
                    '${usageMB.toStringAsFixed(2)} MB',
                    style: AppTheme.bodyStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.7),
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

  Widget _buildLimitsCard(DataUsageTracker tracker) {
    final limits = tracker.limits;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Usage Limits',
                style: AppTheme.subtitleStyle.copyWith(
                  color: AppTheme.getOnSurfaceColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showLimitsDialog(tracker),
                child: Text(
                  'Edit',
                  style: AppTheme.bodyStyle.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLimitItem('Daily', '${limits.dailyLimitMB} MB'),
              _buildLimitItem('Weekly', '${limits.weeklyLimitMB} MB'),
              _buildLimitItem('Monthly', '${limits.monthlyLimitMB} MB'),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                limits.enableWarnings
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: limits.enableWarnings ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                limits.enableWarnings
                    ? 'Warnings enabled'
                    : 'Warnings disabled',
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.bodyStyle.copyWith(
            color: AppTheme.getOnSurfaceColor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: AppTheme.captionStyle.copyWith(
            color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageHistoryCard(DataUsageTracker tracker) {
    final history = tracker.usageHistory
        .where((item) => item.totalUsage > 0)
        .take(7)
        .toList();

    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.history,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent History',
                style: AppTheme.subtitleStyle.copyWith(
                  color: AppTheme.getOnSurfaceColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...history.map((data) {
            final usageMB = tracker.getUsageInMB(data.totalUsage);
            final date = DateFormat('MMM dd').format(data.date);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date,
                    style: AppTheme.bodyStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(context),
                    ),
                  ),
                  Text(
                    '${usageMB.toStringAsFixed(2)} MB',
                    style: AppTheme.bodyStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(context),
                      fontWeight: FontWeight.w500,
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

  Widget _buildPeriodSummaryCard(DataUsageTracker tracker) {
    final weekly = tracker.weeklyUsage;
    final monthly = tracker.monthlyUsage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Period Summary',
            style: AppTheme.subtitleStyle.copyWith(
              color: AppTheme.getOnSurfaceColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPeriodItem(
                  label: 'Weekly',
                  value: '${tracker.getUsageInMB(weekly?.totalUsage ?? 0).toStringAsFixed(2)} MB',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPeriodItem(
                  label: 'Monthly',
                  value: '${tracker.getUsageInMB(monthly?.totalUsage ?? 0).toStringAsFixed(2)} MB',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodItem({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.getOnSurfaceColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackedSourcesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tracked Sources',
            style: AppTheme.subtitleStyle.copyWith(
              color: AppTheme.getOnSurfaceColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildSourceStatus('API / HTTP client', true),
          _buildSourceStatus('Discord Dio requests', true),
          _buildSourceStatus('Downloads', true),
          _buildSourceStatus('Media cache fetches', true),
          _buildSourceStatus('Cache hits (local reads)', false),
        ],
      ),
    );
  }

  Widget _buildSourceStatus(String label, bool tracked) {
    final color = tracked ? Colors.green : Colors.orange;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(tracked ? Icons.check_circle : Icons.info, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getUsageColor(double percentage) {
    if (percentage >= 90) return Colors.red;
    if (percentage >= 75) return Colors.orange;
    return AppTheme.primaryColor;
  }

  Color _getCategoryColor(UsageCategory category) {
    switch (category) {
      case UsageCategory.images:
        return Colors.blue;
      case UsageCategory.videos:
        return Colors.red;
      case UsageCategory.thumbnails:
        return Colors.green;
      case UsageCategory.apiCalls:
        return Colors.purple;
      case UsageCategory.attachments:
        return Colors.orange;
      case UsageCategory.other:
        return Colors.grey;
    }
  }

  String _getCategoryName(UsageCategory category) {
    switch (category) {
      case UsageCategory.images:
        return 'Images';
      case UsageCategory.videos:
        return 'Videos';
      case UsageCategory.thumbnails:
        return 'Thumbnails';
      case UsageCategory.apiCalls:
        return 'API Calls';
      case UsageCategory.attachments:
        return 'Attachments';
      case UsageCategory.other:
        return 'Other';
    }
  }

  void _showLimitsDialog(DataUsageTracker tracker) {
    final dailyController = TextEditingController(
      text: tracker.limits.dailyLimitMB.toString(),
    );
    final weeklyController = TextEditingController(
      text: tracker.limits.weeklyLimitMB.toString(),
    );
    final monthlyController = TextEditingController(
      text: tracker.limits.monthlyLimitMB.toString(),
    );
    var warningEnabled = tracker.limits.enableWarnings;
    var autoDataSaver = tracker.limits.autoDataSaver;
    var warningThreshold = tracker.limits.warningThreshold.toDouble();
    var criticalThreshold = tracker.limits.criticalThreshold.toDouble();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Usage Limits'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dailyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Daily limit (MB)'),
                ),
                TextField(
                  controller: weeklyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weekly limit (MB)'),
                ),
                TextField(
                  controller: monthlyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monthly limit (MB)'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable warnings'),
                  value: warningEnabled,
                  onChanged: (value) => setState(() => warningEnabled = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto data saver (advisory)'),
                  value: autoDataSaver,
                  onChanged: (value) => setState(() => autoDataSaver = value),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Warning threshold: ${warningThreshold.round()}%'),
                ),
                Slider(
                  value: warningThreshold,
                  min: 50,
                  max: 95,
                  divisions: 45,
                  label: warningThreshold.round().toString(),
                  onChanged: (value) => setState(() {
                    warningThreshold = value;
                    criticalThreshold = _normalizeCriticalThreshold(
                      criticalThreshold,
                      warningThreshold,
                    );
                  }),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Critical threshold: ${criticalThreshold.round()}%'),
                ),
                Slider(
                  value: criticalThreshold,
                  min: 51,
                  max: 99,
                  divisions: 48,
                  label: criticalThreshold.round().toString(),
                  onChanged: (value) => setState(() {
                    criticalThreshold = _normalizeCriticalThreshold(
                      value,
                      warningThreshold,
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final daily = int.tryParse(dailyController.text.trim());
                final weekly = int.tryParse(weeklyController.text.trim());
                final monthly = int.tryParse(monthlyController.text.trim());
                if (daily == null || weekly == null || monthly == null) return;
                if (daily <= 0 || weekly <= 0 || monthly <= 0) return;

                tracker.updateLimits(
                  tracker.limits.copyWith(
                    dailyLimitMB: daily,
                    weeklyLimitMB: weekly,
                    monthlyLimitMB: monthly,
                    enableWarnings: warningEnabled,
                    autoDataSaver: autoDataSaver,
                    warningThreshold: warningThreshold.round(),
                    criticalThreshold: criticalThreshold.round(),
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  double _normalizeCriticalThreshold(double value, double warningThreshold) {
    final minAllowed =
        (warningThreshold.roundToDouble() + _minThresholdGap).clamp(51.0, 99.0);
    final normalizedValue = value.roundToDouble();
    return normalizedValue < minAllowed ? minAllowed : normalizedValue;
  }
}

/// A self-contained widget that displays a live mm:ss session duration counter.
///
/// It owns its own 1-second [Timer] so only this widget rebuilds every second,
/// leaving the rest of the dashboard driven purely by [DataUsageTracker] change
/// notifications.
class _SessionClock extends StatefulWidget {
  final DateTime sessionStart;

  const _SessionClock({required this.sessionStart});

  @override
  State<_SessionClock> createState() => _SessionClockState();
}

class _SessionClockState extends State<_SessionClock> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.sessionStart);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.sessionStart);
        });
      }
    });
  }

  @override
  void didUpdateWidget(_SessionClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionStart != widget.sessionStart) {
      _elapsed = DateTime.now().difference(widget.sessionStart);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;
    return Text(
      '${minutes}m ${seconds}s',
      style: AppTheme.bodyStyle.copyWith(
        color: AppTheme.getOnSurfaceColor(context),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
