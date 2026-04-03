import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/member_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/payment_method_provider.dart';
import '../models/payment.dart';
import 'add_payment_dialog.dart';
import '../l10n/app_localizations.dart';

Color? parseColor(dynamic colorValue) {
  if (colorValue is Color) return colorValue;
  if (colorValue is int) return Color(colorValue);
  if (colorValue is String) {
    try {
      final hex = colorValue.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
  }
  return kBrandAccentColor;
}

const kBrandTextColor = Color(0xFF116478);
const kBrandBackgroundColor = Color(0xFFF6F6D7);
const kBrandAccentColor = Color(0xFF8CB2AB);

class PaymentsPage extends ConsumerWidget {
  final String token;
  final bool isAdmin;
  final List<int> instructorSalonIds;

  const PaymentsPage({
    super.key,
    required this.token,
    required this.isAdmin,
    required this.instructorSalonIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final memberState = ref.watch(memberProvider);
    final paymentState = ref.watch(paymentProvider);
    // final salons = ref.watch(salonsProvider); // Not used in this widget

    return Scaffold(
      backgroundColor: kBrandBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc?.translate('payments') ?? 'Payments',
          style: const TextStyle(color: kBrandTextColor),
        ),
        backgroundColor: kBrandBackgroundColor,
        iconTheme: const IconThemeData(color: kBrandTextColor),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: kBrandAccentColor),
            tooltip: loc?.translate('add') ?? 'Add Payment',
            onPressed: memberState.status == MemberStatus.loaded
                ? () async {
                    final result = await showDialog(
                      context: context,
                      builder: (ctx) => AddPaymentDialog(
                        members: isAdmin
                            ? memberState.members
                            : memberState.members
                                  .where(
                                    (m) => instructorSalonIds.any(
                                      (id) => m.assignedSalonIds.contains(id),
                                    ),
                                  )
                                  .toList(),
                        token: token,
                      ),
                    );
                    if (result == true) {
                      ref.read(memberProvider.notifier).fetchMembers(token);
                      ref.read(paymentProvider.notifier).fetchPayments(token);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            loc?.translate('add') ??
                                'Payment added successfully',
                          ),
                          backgroundColor: kBrandAccentColor,
                        ),
                      );
                    }
                  }
                : null,
          ),
          const Padding(padding: EdgeInsets.only(right: 8.0)),
        ],
      ),
      body: memberState.status == MemberStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : memberState.status == MemberStatus.error
          ? Center(
              child: Text(
                memberState.error ?? 'Error',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : ListView.builder(
              itemCount: memberState.members.length,
              itemBuilder: (context, idx) {
                final member = memberState.members[idx];
                if (!isAdmin &&
                    !instructorSalonIds.any(
                      (id) => member.assignedSalonIds.contains(id),
                    )) {
                  return const SizedBox.shrink();
                }
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: parseColor(member.memberTypeColor),
                      child: Text(
                        member.name[0],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      member.name,
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    subtitle: Text(
                      '${loc?.translate('totalDebt') ?? 'Debt'}: ${loc?.translate('currencySymbol') ?? '₺'}${member.totalDebt.toStringAsFixed(2)}',
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, color: kBrandAccentColor),
                          onPressed: () async {
                            final result = await showDialog(
                              context: context,
                              builder: (ctx) => PaymentFormDialog(
                                memberId: member.id,
                                token: token,
                              ),
                            );
                            if (result == true) {
                              ref
                                  .read(memberProvider.notifier)
                                  .fetchMembers(token);
                              ref
                                  .read(paymentProvider.notifier)
                                  .fetchPayments(token);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc?.translate('add') ??
                                        'Payment added successfully',
                                  ),
                                  backgroundColor: kBrandAccentColor,
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final payments =
                                paymentState.value
                                    ?.where((p) => p.memberId == member.id)
                                    .toList() ??
                                [];
                            if (payments.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc?.translate('delete') ??
                                        'No payments to delete',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final selected = await showDialog<Payment>(
                              context: context,
                              builder: (ctx) => SimpleDialog(
                                title: Text(
                                  loc?.translate('delete') ??
                                      'Select Payment to Delete',
                                ),
                                children: payments
                                    .map(
                                      (p) => SimpleDialogOption(
                                        child: Text(
                                          '${loc?.translate('currencySymbol') ?? '₺'}${p.amount} - ${p.method} - ${p.date.toLocal().toString().split(' ')[0]}',
                                        ),
                                        onPressed: () => Navigator.pop(ctx, p),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                            if (selected != null) {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    loc?.translate('delete') ??
                                        'Confirm Deletion',
                                  ),
                                  content: Text(
                                    loc?.translate('delete') ??
                                        'Are you sure you want to delete this payment?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(
                                        loc?.translate('cancel') ?? 'Cancel',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(
                                        loc?.translate('delete') ?? 'Delete',
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final ok = await ref
                                    .read(paymentProvider.notifier)
                                    .deletePayment(selected.id, token);
                                if (ok) {
                                  ref
                                      .read(memberProvider.notifier)
                                      .fetchMembers(token);
                                  ref
                                      .read(paymentProvider.notifier)
                                      .fetchPayments(token);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        loc?.translate('delete') ??
                                            'Payment deleted',
                                      ),
                                      backgroundColor: kBrandAccentColor,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        loc?.translate('delete') ??
                                            'Failed to delete payment',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PaymentFormDialog extends ConsumerStatefulWidget {
  final int memberId;
  final String token;
  const PaymentFormDialog({
    super.key,
    required this.memberId,
    required this.token,
  });

  @override
  ConsumerState<PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends ConsumerState<PaymentFormDialog> {
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
    final loc = AppLocalizations.of(context);
    final methodsAsync = ref.watch(paymentMethodProvider);
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        loc?.translate('add') ?? 'Add Payment',
        style: const TextStyle(color: kBrandTextColor),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            methodsAsync.when(
              data: (methods) => DropdownButtonFormField<String>(
                value: _selectedMethod,
                items: methods
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedMethod = v),
                decoration: InputDecoration(
                  labelText: loc?.translate('method') ?? 'Payment Method',
                ),
                validator: (v) => v == null
                    ? (loc?.translate('method') ?? 'Select a method')
                    : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                '${loc?.translate('error') ?? 'Error'}: $e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText:
                    '${loc?.translate('amount') ?? 'Amount'} (${loc?.translate('currencySymbol') ?? '₺'})',
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0)
                  return loc?.translate('amount') ?? 'Enter a positive amount';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? (loc?.translate('date') ?? 'Select Date')
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
          child: Text(loc?.translate('cancel') ?? 'Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kBrandAccentColor),
          onPressed: _loading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate() ||
                      _selectedMethod == null ||
                      _selectedDate == null)
                    return;
                  setState(() => _loading = true);
                  final ok = await ref
                      .read(paymentProvider.notifier)
                      .addPayment(
                        Payment(
                          id: 0,
                          memberId: widget.memberId,
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
                      SnackBar(
                        content: Text(
                          loc?.translate('add') ?? 'Failed to add payment',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
          child: _loading
              ? const CircularProgressIndicator()
              : Text(
                  loc?.translate('save') ?? 'Submit',
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
