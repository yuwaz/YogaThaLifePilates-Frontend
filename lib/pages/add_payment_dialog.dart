import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/payment_method_provider.dart';
import '../providers/payment_provider.dart';
import '../models/payment.dart';

const kBrandTextColor = Color(0xFF116478);
const kBrandAccentColor = Color(0xFF8CB2AB);

class AddPaymentDialog extends ConsumerStatefulWidget {
  final List members;
  final String token;
  const AddPaymentDialog({
    super.key,
    required this.members,
    required this.token,
  });

  @override
  ConsumerState<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends ConsumerState<AddPaymentDialog> {
  int? _selectedMemberId;
  String? _selectedMethod;
  DateTime? _selectedDate;
  final _amountController = TextEditingController();
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(paymentMethodProvider);
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'Add Payment',
        style: TextStyle(color: kBrandTextColor),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _selectedMemberId,
              items: widget.members
                  .map<DropdownMenuItem<int>>(
                    (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedMemberId = v),
              decoration: const InputDecoration(labelText: 'Member'),
              validator: (v) => v == null ? 'Select a member' : null,
            ),
            const SizedBox(height: 12),
            methodsAsync.when(
              data: (methods) => DropdownButtonFormField<String>(
                value: _selectedMethod,
                items: methods
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedMethod = v),
                decoration: const InputDecoration(labelText: 'Payment Method'),
                validator: (v) => v == null ? 'Select a method' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) =>
                  Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₺)'),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a positive amount';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'Select Date'
                        : _selectedDate!.toLocal().toString().split(' ')[0],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.calendar_today,
                    color: kBrandAccentColor,
                  ),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 1),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kBrandAccentColor),
          onPressed: _loading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate() ||
                      _selectedMemberId == null ||
                      _selectedMethod == null ||
                      _selectedDate == null)
                    return;
                  setState(() => _loading = true);
                  final ok = await ref
                      .read(paymentProvider.notifier)
                      .addPayment(
                        Payment(
                          id: 0,
                          memberId: _selectedMemberId!,
                          amount: double.parse(_amountController.text),
                          method: _selectedMethod!,
                          date: _selectedDate!,
                        ),
                        widget.token,
                      );
                  setState(() => _loading = false);
                  if (ok) {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to add payment'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Submit', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
