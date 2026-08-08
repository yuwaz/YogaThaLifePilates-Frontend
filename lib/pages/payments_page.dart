import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/member_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/payment_method_provider.dart';
import '../providers/salons_provider.dart';
import '../models/expense.dart';
import '../models/payment.dart';
// import 'add_payment_dialog.dart';

import '../l10n/app_localizations.dart';
import 'member_payment_details_page.dart';
import '../utils/currency_formatter.dart';

// PaymentFormDialog for adding a payment
class PaymentFormDialog extends ConsumerStatefulWidget {
  final int memberId;
  final String token;
  final Payment? initialPayment;
  const PaymentFormDialog({
    super.key,
    required this.memberId,
    required this.token,
    this.initialPayment,
  });

  @override
  ConsumerState<PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends ConsumerState<PaymentFormDialog> {
  int? _selectedPaymentMethodId;
  // Removed unused _selectedPaymentMethodName
  DateTime? _selectedDate;
  late TextEditingController _amountController;
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialPayment != null) {
      _selectedPaymentMethodId = widget.initialPayment!.paymentMethodId;
    }
    _selectedDate = widget.initialPayment?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: widget.initialPayment != null
          ? widget.initialPayment!.amount.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final methodsAsync = ref.watch(paymentMethodProvider(widget.token));
    final isEdit = widget.initialPayment != null;
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        isEdit
            ? (loc?.translate('edit') ?? 'Ödeme Düzenle')
            : (loc?.translate('add') ?? 'Ödeme Ekle'),
        style: const TextStyle(color: kBrandTextColor),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            methodsAsync.when(
              data: (methods) {
                List<Map<String, dynamic>> methodObjs = [];
                if (methods.isNotEmpty &&
                    methods.first is Map<String, dynamic>) {
                  methodObjs = List<Map<String, dynamic>>.from(methods);
                } else if (methods.isNotEmpty) {
                  methodObjs = List.generate(
                    methods.length,
                    (i) => {'id': i + 1, 'name': methods[i]},
                  );
                }
                return DropdownButtonFormField<int>(
                  value: _selectedPaymentMethodId,
                  items: methodObjs
                      .map(
                        (m) => DropdownMenuItem(
                          value: m['id'] as int,
                          child: Text(m['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedPaymentMethodId = v;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Ödeme Yöntemi'),
                  validator: (v) => v == null ? 'Ödeme yöntemi seçin' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                e is Exception && e.toString().contains(': ')
                    ? e.toString().split(': ').last
                    : (e.toString().isNotEmpty
                          ? e.toString()
                          : 'Failed to fetch payment methods'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tutar',
                prefixText: '₺',
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Pozitif bir tutar girin';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'Tarih: \\${DateTime.now().toLocal().toString().split(' ')[0]}'
                        : 'Tarih: \\${_selectedDate!.toLocal().toString().split(' ')[0]}',
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
                      initialDate: _selectedDate ?? now,
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
          child: Text(loc?.translate('cancel') ?? 'İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kBrandAccentColor),
          onPressed: _loading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate() ||
                      _selectedPaymentMethodId == null ||
                      _selectedDate == null) {
                    return;
                  }
                  setState(() => _loading = true);
                  String? error;
                  if (isEdit) {
                    final updateBody = {
                      'id': widget.initialPayment!.id,
                      'memberId': widget.memberId,
                      'amount': double.parse(_amountController.text),
                      'paymentMethodId': _selectedPaymentMethodId,
                      'date': _selectedDate!.toIso8601String(),
                    };
                    error = await ref
                        .read(paymentProvider.notifier)
                        .updatePayment(updateBody, widget.token);
                  } else {
                    error = await ref
                        .read(paymentProvider.notifier)
                        .addPayment({
                          'memberId': widget.memberId,
                          'amount': double.parse(_amountController.text),
                          'paymentMethodId': _selectedPaymentMethodId,
                          'date': _selectedDate!.toIso8601String(),
                        }, widget.token);
                  }
                  setState(() => _loading = false);
                  if (mounted) {
                    if (error == null) {
                      Navigator.pop(
                        context,
                        isEdit ? 'success:edited' : 'success:created',
                      );
                    } else {
                      Navigator.pop(context, error);
                    }
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

class ExpenseFormDialog extends ConsumerStatefulWidget {
  final String token;
  final List<int> instructorSalonIds;
  final Expense? initialExpense;
  const ExpenseFormDialog({
    super.key,
    required this.token,
    required this.instructorSalonIds,
    this.initialExpense,
  });

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedPaymentMethodId;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;

  static const List<String> _categories = [
    'Kira',
    'Maaş',
    'Malzeme',
    'Fatura',
    'Reklam',
    'Temizlik',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialExpense;
    if (initial != null) {
      _titleController.text = initial.title;
      _amountController.text = initial.amount.toString();
      _selectedCategory = initial.category;
      _selectedDate = initial.date;
      _selectedPaymentMethodId = initial.paymentMethodId;
      _notesController.text = initial.notes ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(paymentMethodProvider(widget.token));
    final salonsState = ref.watch(salonsProvider);
    final isEdit = widget.initialExpense != null;

    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        isEdit ? 'Gider Düzenle' : 'Gider Ekle',
        style: const TextStyle(color: kBrandTextColor),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Başlık zorunludur';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tutar',
                    prefixText: '₺',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (n == null || n <= 0) {
                      return 'Geçerli bir tutar girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: _categories
                      .map(
                        (c) =>
                            DropdownMenuItem<String>(value: c, child: Text(c)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Kategori seçin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                methodsAsync.when(
                  data: (methods) {
                    final methodObjs = List.generate(
                      methods.length,
                      (i) => {'id': i + 1, 'name': methods[i]},
                    );

                    return DropdownButtonFormField<int>(
                      value: _selectedPaymentMethodId,
                      decoration: const InputDecoration(
                        labelText: 'Ödeme Yöntemi (Opsiyonel)',
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Seçilmedi'),
                        ),
                        ...methodObjs.map(
                          (m) => DropdownMenuItem<int>(
                            value: m['id'] as int,
                            child: Text(m['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedPaymentMethodId = v);
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tarih: ${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
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
                          initialDate: _selectedDate,
                          firstDate: DateTime(now.year - 3),
                          lastDate: DateTime(now.year + 3),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notlar'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kBrandAccentColor),
          onPressed: _loading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;

                  setState(() => _loading = true);

                  final fallbackSalonId = widget.instructorSalonIds.isNotEmpty
                      ? widget.instructorSalonIds.first
                      : (salonsState.salons.isNotEmpty
                            ? salonsState.salons.first.id
                            : null);

                  if (fallbackSalonId == null) {
                    setState(() => _loading = false);
                    if (!mounted) return;
                    Navigator.pop(context, 'Gider kaydı için salon bulunamadı');
                    return;
                  }

                  final parsedAmount = double.parse(
                    _amountController.text.trim().replaceAll(',', '.'),
                  );

                  final notes = _notesController.text.trim();
                  final body = {
                    'salonId': fallbackSalonId,
                    'title': _titleController.text.trim(),
                    'amount': parsedAmount,
                    'category': _selectedCategory,
                    'date': _formatDate(_selectedDate),
                    'paymentMethodId': _selectedPaymentMethodId,
                    'notes': notes.isEmpty ? null : notes,
                  };

                  final error = isEdit
                      ? await ref
                            .read(expenseProvider.notifier)
                            .updateExpense(
                              widget.token,
                              widget.initialExpense!.id,
                              body,
                            )
                      : await ref
                            .read(expenseProvider.notifier)
                            .addExpense(widget.token, body);

                  setState(() => _loading = false);

                  if (!mounted) return;

                  if (error == null) {
                    Navigator.pop(
                      context,
                      isEdit ? 'success:edited' : 'success:created',
                    );
                  } else {
                    Navigator.pop(context, error);
                  }
                },
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kaydet', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

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

class PaymentsPage extends ConsumerStatefulWidget {
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
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  @override
  void initState() {
    super.initState();
    // Ensure payment history loads immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentProvider.notifier).fetchPayments(widget.token);
      ref.read(expenseProvider.notifier).fetchExpenses(widget.token);
    });
  }

  String _paymentSearchQuery = '';
  int _selectedTabIndex = 0;
  String _selectedSort = 'debt_desc';
  final GlobalKey _sortButtonKey = GlobalKey();
  Timer? _searchDebounce;
  List<dynamic> _filteredMembers = const [];
  List<Payment> _filteredPayments = const [];
  List<Expense> _filteredExpenses = const [];
  List<dynamic>? _lastMembersSource;
  List<Payment>? _lastPaymentsSource;
  List<Expense>? _lastExpensesSource;
  bool _needsFinanceRecompute = true;

  Future<void> _refreshFinanceData() async {
    await ref.read(paymentProvider.notifier).fetchPayments(widget.token);
    await ref.read(expenseProvider.notifier).fetchExpenses(widget.token);
    await ref.read(memberProvider.notifier).fetchMembers(widget.token);
  }

  void _markFinanceDirty() {
    _needsFinanceRecompute = true;
  }

  void _recomputeFinance(
    List<dynamic> members,
    List<Payment> payments,
    List<Expense> expenses,
  ) {
    final filteredMembers = members
        .where(
          (m) =>
              m.name.toLowerCase().contains(_paymentSearchQuery.toLowerCase()),
        )
        .toList();
    filteredMembers.sort((a, b) {
      switch (_selectedSort) {
        case 'debt_asc':
          return _memberDebt(a).compareTo(_memberDebt(b));
        case 'name_asc':
          return _compareName(a, b, ascending: true);
        case 'name_desc':
          return _compareName(a, b, ascending: false);
        case 'debt_desc':
        default:
          return _memberDebt(b).compareTo(_memberDebt(a));
      }
    });

    final filteredPayments = [...payments];
    filteredPayments.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return b.id.compareTo(a.id);
    });

    final filteredExpenses = [...expenses];
    filteredExpenses.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return b.id.compareTo(a.id);
    });

    _filteredMembers = filteredMembers;
    _filteredPayments = filteredPayments;
    _filteredExpenses = filteredExpenses;
    _needsFinanceRecompute = false;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Widget _buildPullPlaceholder(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(child: child),
      ],
    );
  }

  String _sortLabel() {
    switch (_selectedSort) {
      case 'debt_asc':
        return 'Sırala: Borç Artan';
      case 'name_asc':
        return 'Sırala: İsim A-Z';
      case 'name_desc':
        return 'Sırala: İsim Z-A';
      case 'debt_desc':
      default:
        return 'Sırala: Borç Azalan';
    }
  }

  double _memberDebt(dynamic member) {
    final value = member.totalDebt;
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _memberName(dynamic member) {
    final value = member.name;
    if (value == null) return '';
    return value.toString().trim();
  }

  int _compareName(dynamic a, dynamic b, {required bool ascending}) {
    final aName = _memberName(a);
    final bName = _memberName(b);
    final aEmpty = aName.isEmpty;
    final bEmpty = bName.isEmpty;

    if (aEmpty && bEmpty) return 0;
    if (aEmpty) return 1;
    if (bEmpty) return -1;

    final cmp = aName.toLowerCase().compareTo(bName.toLowerCase());
    return ascending ? cmp : -cmp;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final paymentState = ref.watch(paymentProvider);
    final expenseState = ref.watch(expenseProvider);
    final memberState = ref.watch(memberProvider);
    final members = memberState.members;
    final payments = paymentState.value ?? [];
    final memberMap = {for (var m in members) m.id: m};
    final expenses = expenseState.value ?? [];

    if (!identical(_lastMembersSource, members)) {
      _lastMembersSource = members;
      _markFinanceDirty();
    }
    if (!identical(_lastPaymentsSource, payments)) {
      _lastPaymentsSource = payments;
      _markFinanceDirty();
    }
    if (!identical(_lastExpensesSource, expenses)) {
      _lastExpensesSource = expenses;
      _markFinanceDirty();
    }
    if (_needsFinanceRecompute) {
      _recomputeFinance(members, payments, expenses);
    }

    return Scaffold(
      backgroundColor: kBrandBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 46,
        backgroundColor: const Color(0xFF116478),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            loc?.translate('payments') ?? 'Ödemeler',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: loc?.translate('search') ?? 'Ara',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onChanged: (v) {
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 200),
                            () {
                              if (!mounted) return;
                              setState(() {
                                _paymentSearchQuery = v;
                                _markFinanceDirty();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: _sortButtonKey,
                        icon: const Icon(Icons.sort, color: Color(0xFF116478)),
                        label: Text(
                          _sortLabel(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF116478)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF116478)),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final ctx = _sortButtonKey.currentContext;
                          if (ctx == null) return;
                          final box = ctx.findRenderObject() as RenderBox;
                          final overlay =
                              Overlay.of(context).context.findRenderObject()
                                  as RenderBox;
                          final rect = Rect.fromPoints(
                            box.localToGlobal(Offset.zero, ancestor: overlay),
                            box.localToGlobal(
                              box.size.bottomRight(Offset.zero),
                              ancestor: overlay,
                            ),
                          );

                          final selected = await showMenu<String>(
                            context: context,
                            position: RelativeRect.fromRect(
                              rect,
                              Offset.zero & overlay.size,
                            ),
                            items: const [
                              PopupMenuItem(
                                value: 'debt_desc',
                                child: Text('Borç Azalan'),
                              ),
                              PopupMenuItem(
                                value: 'debt_asc',
                                child: Text('Borç Artan'),
                              ),
                              PopupMenuItem(
                                value: 'name_asc',
                                child: Text('İsim A-Z'),
                              ),
                              PopupMenuItem(
                                value: 'name_desc',
                                child: Text('İsim Z-A'),
                              ),
                            ],
                          );

                          if (selected != null && mounted) {
                            setState(() {
                              _selectedSort = selected;
                              _markFinanceDirty();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 0
                              ? kBrandAccentColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Üyeler',
                            style: TextStyle(
                              color: _selectedTabIndex == 0
                                  ? Colors.white
                                  : kBrandTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 1
                              ? kBrandAccentColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Ödemeler',
                            style: TextStyle(
                              color: _selectedTabIndex == 1
                                  ? Colors.white
                                  : kBrandTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 2
                              ? kBrandAccentColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Giderler',
                            style: TextStyle(
                              color: _selectedTabIndex == 2
                                  ? Colors.white
                                  : kBrandTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshFinanceData,
                child: _selectedTabIndex == 0
                    ? ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, idx) {
                          final member = _filteredMembers[idx];
                          // Removed unused memberPayments
                          return Card(
                            key: ValueKey('${member.id}-${member.totalDebt}'),
                            color: Colors.white,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => MemberPaymentDetailsPage(
                                      memberId: member.id,
                                      memberName: member.name,
                                      token: widget.token,
                                    ),
                                  ),
                                );
                              },
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: parseColor(
                                    member.memberTypeColor,
                                  ),
                                  child: Text(
                                    member.name.isNotEmpty
                                        ? member.name[0]
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  member.name,
                                  style: const TextStyle(
                                    color: kBrandTextColor,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      (loc?.translate('totalDebt') ??
                                              'Total Debt') +
                                          ': ',
                                      style: const TextStyle(
                                        color: kBrandTextColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(member.totalDebt),
                                      style: const TextStyle(
                                        color: kBrandTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: kBrandAccentColor,
                                  ),
                                  tooltip:
                                      loc?.translate('add') ?? 'Add Payment',
                                  onPressed: () async {
                                    final result = await showDialog(
                                      context: context,
                                      builder: (ctx) => PaymentFormDialog(
                                        memberId: member.id,
                                        token: widget.token,
                                      ),
                                    );
                                    final isSuccess =
                                        result is String &&
                                        result.startsWith('success:');
                                    if (isSuccess) {
                                      await ref
                                          .read(memberProvider.notifier)
                                          .fetchMembers(widget.token);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              loc?.translate('add') ??
                                                  'Payment added successfully',
                                            ),
                                            backgroundColor: kBrandAccentColor,
                                          ),
                                        );
                                      }
                                    } else if (result is String &&
                                        result.isNotEmpty) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(result),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : _selectedTabIndex == 1
                    ? paymentState is AsyncLoading
                          ? _buildPullPlaceholder(
                              const CircularProgressIndicator(),
                            )
                          : paymentState is AsyncError
                          ? _buildPullPlaceholder(
                              Text(
                                paymentState.error?.toString() ??
                                    (loc?.translate('error') ?? 'Error'),
                                style: const TextStyle(color: Colors.red),
                              ),
                            )
                          : _filteredPayments.isEmpty
                          ? _buildPullPlaceholder(
                              Text(
                                'Henüz ödeme kaydı yok',
                                style: const TextStyle(color: kBrandTextColor),
                              ),
                            )
                          : (() {
                              return ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 120),
                                itemCount: _filteredPayments.length,
                                itemBuilder: (context, idx) {
                                  final p = _filteredPayments[idx];
                                  final member = memberMap[p.memberId];
                                  final memberName =
                                      member?.name ?? 'Üye ID: \\${p.memberId}';
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        backgroundColor: parseColor(
                                          member?.memberTypeColor,
                                        ),
                                        child: Text(
                                          member?.name != null &&
                                                  member!.name.isNotEmpty
                                              ? member.name[0]
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        memberName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: kBrandTextColor,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                '₺${p.amount.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                p.method,
                                                style: const TextStyle(
                                                  color: kBrandAccentColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${p.date.day.toString().padLeft(2, '0')}.${p.date.month.toString().padLeft(2, '0')}.${p.date.year}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            })()
                    : expenseState is AsyncLoading
                    ? _buildPullPlaceholder(const CircularProgressIndicator())
                    : expenseState is AsyncError
                    ? _buildPullPlaceholder(
                        Text(
                          expenseState.error?.toString() ??
                              (loc?.translate('error') ?? 'Error'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : (() {
                        if (_filteredExpenses.isEmpty) {
                          return _buildPullPlaceholder(
                            const Text(
                              'Henüz gider kaydı yok',
                              style: TextStyle(color: kBrandTextColor),
                            ),
                          );
                        }

                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 120),
                          itemCount: _filteredExpenses.length,
                          itemBuilder: (context, idx) {
                            final e = _filteredExpenses[idx];
                            final notes = e.notes?.trim() ?? '';
                            final hasNotes = notes.isNotEmpty;
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  e.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: kBrandTextColor,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '₺${e.amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            e.category,
                                            style: const TextStyle(
                                              color: kBrandAccentColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${e.date.day.toString().padLeft(2, '0')}.${e.date.month.toString().padLeft(2, '0')}.${e.date.year}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    if (hasNotes)
                                      Text(
                                        notes,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: kBrandAccentColor,
                                      ),
                                      onPressed: () async {
                                        final result = await showDialog(
                                          context: context,
                                          builder: (ctx) => ExpenseFormDialog(
                                            token: widget.token,
                                            instructorSalonIds:
                                                widget.instructorSalonIds,
                                            initialExpense: e,
                                          ),
                                        );

                                        if (!context.mounted) return;

                                        if (result is String &&
                                            result.startsWith('success:')) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Gider güncellendi',
                                              ),
                                              backgroundColor:
                                                  kBrandAccentColor,
                                            ),
                                          );
                                        } else if (result is String &&
                                            result.isNotEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(result),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        final shouldDelete = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) {
                                            return AlertDialog(
                                              title: const Text('Sil'),
                                              content: const Text(
                                                'Bu gideri silmek istiyor musunuz?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        false,
                                                      ),
                                                  child: const Text('Vazgeç'),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Sil',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (shouldDelete != true) return;

                                        final error = await ref
                                            .read(expenseProvider.notifier)
                                            .deleteExpense(widget.token, e.id);

                                        if (!context.mounted) return;

                                        if (error == null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Gider silindi'),
                                              backgroundColor:
                                                  kBrandAccentColor,
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(error),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      })(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTabIndex == 2
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF116478),
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () async {
                final result = await showDialog(
                  context: context,
                  builder: (ctx) => ExpenseFormDialog(
                    token: widget.token,
                    instructorSalonIds: widget.instructorSalonIds,
                  ),
                );

                if (!context.mounted) return;

                if (result is String && result.startsWith('success:')) {
                  await ref
                      .read(expenseProvider.notifier)
                      .fetchExpenses(widget.token);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gider eklendi'),
                        backgroundColor: kBrandAccentColor,
                      ),
                    );
                  }
                } else if (result is String && result.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            )
          : null,
    );
  }
}
