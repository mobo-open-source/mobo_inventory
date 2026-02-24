import 'package:flutter/material.dart';

/// A simple utility class for showing a modal quantity input dialog.
class QuantityDialog {
  static Future<double?> show(
    BuildContext context, {
    String title = 'Enter Quantity',
    double initialValue = 1.0,
  }) {
    final controller = TextEditingController(text: initialValue.toString());

    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.pop(ctx, value);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
