import 'package:flutter/material.dart';

class TransactionEntry {
  final String title;
  final String subtitle;
  final String amountLabel;
  final IconData icon;
  final Color iconColor;
  final DateTime createdAt;
  final String createdAtLabel; // pre-formatted, UTC+08:00

  // Only populated for top-up entries - used to drive refund eligibility.
  final String? topupId;
  final String? refundStatus; // 'none' | 'pending' | 'refunded'
  final bool isTopup;

  TransactionEntry({
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    required this.icon,
    required this.iconColor,
    required this.createdAt,
    required this.createdAtLabel,
    this.topupId,
    this.refundStatus,
    this.isTopup = false,
  });

  // Formats a UTC DateTime as UTC+08:00, e.g. "31 Aug 2026, 3:45 PM".
  static String _formatUtc8(DateTime utcTime) {
    final local = utcTime.toUtc().add(const Duration(hours: 8));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '$hour12:$minute $period (UTC+8)';
  }

  // Returns null (instead of throwing) if the row is missing required
  // fields, so one malformed row doesn't crash the whole list.
  static TransactionEntry? tryTrade(Map<String, dynamic> row) {
    final createdAtRaw = row['created_at'] as String?;
    final createdAt =
    createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;
    if (createdAt == null) return null;

    final side = row['side'] as String? ?? 'buy';
    final symbol = row['symbol'] as String? ?? '???';
    final quantity = (row['quantity'] as num?)?.toDouble() ?? 0.0;
    final price = (row['price'] as num?)?.toDouble() ?? 0.0;
    final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
    final isBuy = side == 'buy';

    return TransactionEntry(
      title: '${isBuy ? "Bought" : "Sold"} $symbol',
      subtitle:
      '${quantity.toStringAsFixed(4)} shares @ RM ${price.toStringAsFixed(2)}\n'
          '${_formatUtc8(createdAt)}',
      amountLabel: '${isBuy ? "-" : "+"}RM ${amount.toStringAsFixed(2)}',
      icon: isBuy ? Icons.trending_up : Icons.trending_down,
      iconColor: isBuy ? Colors.green : Colors.red,
      createdAt: createdAt,
      createdAtLabel: _formatUtc8(createdAt),
      isTopup: false,
    );
  }

  static TransactionEntry? tryTopup(
      Map<String, dynamic> row,
      Map<String, String> refundStatusByTopupId,
      ) {
    final createdAtRaw = row['created_at'] as String?;
    final createdAt =
    createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;
    if (createdAt == null) return null;

    final id = row['id'] as String?;
    final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
    final method = row['method'] as String? ?? 'manual';
    final status = row['status'] as String? ?? 'completed';
    final refundStatus = id != null ? refundStatusByTopupId[id] : null;
    final methodLabel = method.isNotEmpty
        ? '${method[0].toUpperCase()}${method.substring(1)}'
        : method;

    return TransactionEntry(
      title: 'Top Up',
      subtitle: '$methodLabel · $status'
          '${refundStatus != null ? ' · Refund $refundStatus' : ''}\n'
          '${_formatUtc8(createdAt)}',
      amountLabel: '+RM ${amount.toStringAsFixed(2)}',
      icon: Icons.account_balance_wallet_outlined,
      iconColor: Colors.blue,
      createdAt: createdAt,
      createdAtLabel: _formatUtc8(createdAt),
      topupId: id,
      refundStatus: refundStatus,
      isTopup: true,
    );
  }
}