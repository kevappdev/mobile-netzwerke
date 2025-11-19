import 'package:flutter/material.dart';

class Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const Section({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class MonospaceBox extends StatelessWidget {
  final String text;
  const MonospaceBox({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

class KeyValueRow extends StatelessWidget {
  final String label;
  final Object? value;
  const KeyValueRow(this.label, this.value, {super.key});

  String _fmt(Object? v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Ja' : 'Nein';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(_fmt(value), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
          ],
        ),
      ),
    );
  }
}


