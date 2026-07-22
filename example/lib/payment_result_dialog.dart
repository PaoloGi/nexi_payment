import 'package:flutter/material.dart';

/// The three ways a payment attempt can end, shared by both gateways.
enum PaymentResultKind { success, canceled, error }

/// Shows a polished outcome dialog: a colored icon badge, a clear title and
/// an optional detail line (gateway response, error code, order id...).
Future<void> showPaymentResultDialog(
  BuildContext context,
  PaymentResultKind kind, {
  String? detail,
}) {
  final (IconData icon, Color color, String title) = switch (kind) {
    PaymentResultKind.success => (
      Icons.check_circle_rounded,
      Colors.green,
      'Payment successful',
    ),
    PaymentResultKind.canceled => (
      Icons.highlight_off_rounded,
      Colors.orange,
      'Payment canceled',
    ),
    PaymentResultKind.error => (
      Icons.error_rounded,
      Colors.red,
      'Payment failed',
    ),
  };

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (detail != null && detail.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              // A long detail (e.g. the RESULT_PARSING_FAILED message) must
              // scroll inside the dialog rather than overflow it on a short
              // screen; Flexible lets the scroll view shrink to fit.
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    detail,
                    key: const Key('paymentResult'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CLOSE'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
