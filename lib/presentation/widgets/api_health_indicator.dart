import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/api_health_provider.dart';
import '../theme/app_theme.dart';

class ApiHealthIndicator extends StatelessWidget {
  final bool compact;
  
  const ApiHealthIndicator({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiHealthProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusChip(context, 'K', provider.kemonoStatus),
              const SizedBox(width: 8),
              _buildStatusChip(context, 'C', provider.coomerStatus),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => provider.checkHealth(),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: compact ? 14 : 16,
                      color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(BuildContext context, String label, ApiStatus status) {
    Color statusColor;
    String statusTooltip;
    
    switch (status) {
      case ApiStatus.online:
        statusColor = Colors.green;
        statusTooltip = 'Online';
        break;
      case ApiStatus.rateLimited:
        statusColor = Colors.amber;
        statusTooltip = 'Rate Limited';
        break;
      case ApiStatus.offline:
        statusColor = Colors.red;
        statusTooltip = 'Offline';
        break;
      case ApiStatus.checking:
        statusColor = Colors.grey;
        statusTooltip = 'Checking...';
        break;
    }

    return Tooltip(
      message: '$label: $statusTooltip',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.getOnSurfaceColor(context),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: compact ? 8 : 10,
            height: compact ? 8 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
