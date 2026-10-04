class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.users,
    required this.activeWagers,
    required this.pendingPayments,
    this.pendingWithdrawals = 0,
    required this.transactions,
    required this.availableCents,
    required this.lockedCents,
  });

  factory AdminDashboardSummary.fromJson(Map<String, Object?> json) =>
      AdminDashboardSummary(
        users: (json['users'] as num? ?? 0).toInt(),
        activeWagers: (json['active_wagers'] as num? ?? 0).toInt(),
        pendingPayments: (json['pending_payments'] as num? ?? 0).toInt(),
        pendingWithdrawals:
            (json['pending_withdrawals'] as num? ?? 0).toInt(),
        transactions: (json['transactions'] as num? ?? 0).toInt(),
        availableCents: (json['available_cents'] as num? ?? 0).toInt(),
        lockedCents: (json['locked_cents'] as num? ?? 0).toInt(),
      );

  final int users;
  final int activeWagers;
  final int pendingPayments;

  /// Withdrawal requests waiting for an administrator to approve or reject.
  final int pendingWithdrawals;
  final int transactions;
  final int availableCents;
  final int lockedCents;
}
