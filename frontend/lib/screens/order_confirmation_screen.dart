import 'package:flutter/material.dart';
import '../models/order.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final Order order;
  const OrderConfirmationScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Order Confirmed!',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Thank you for supporting independent artisans.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _SummaryCard(order: order),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.storefront),
                label: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Order order;
  const _SummaryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(label: 'Order ID', value: order.id.substring(0, 8).toUpperCase()),
            _Row(label: 'Product', value: order.productTitle),
            _Row(label: 'Buyer', value: order.buyerName),
            _Row(label: 'Email', value: order.buyerEmail),
            _Row(label: 'Quantity', value: '${order.quantity}'),
            const Divider(),
            _Row(
              label: 'Total Paid',
              value: '₹${order.totalPrice.toStringAsFixed(2)}',
              bold: true,
              valueColor: theme.colorScheme.primary,
            ),
            _Row(label: 'Status', value: order.status.toUpperCase()),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.bold : null,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
