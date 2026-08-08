import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/equipment.dart';
import '../models/salon.dart';
import '../providers/equipment_provider.dart';
import '../providers/member_types_provider.dart' as member_types;
import '../providers/payment_methods_provider.dart' as payment_methods;
import '../providers/salons_provider.dart';
import '../providers/studio_onboarding_provider.dart';
import 'main_page.dart';

const kBrandTextColor = Color(0xFF116478);
const kBrandBackgroundColor = Color(0xFFF6F6D7);
const kBrandAccentColor = Color(0xFF8CB2AB);

const List<String> _memberTypeColorHexes = [
  '#F08080',
  '#F0A09F',
  '#DEE0C2',
  '#B7DF9C',
  '#8CD6BA',
  '#83A8C3',
];

class StudioOnboardingPage extends ConsumerStatefulWidget {
  final String studioName;
  final String studioCode;
  final String? trialEndsAt;

  const StudioOnboardingPage({
    super.key,
    required this.studioName,
    required this.studioCode,
    this.trialEndsAt,
  });

  @override
  ConsumerState<StudioOnboardingPage> createState() =>
      _StudioOnboardingPageState();
}

class _StudioOnboardingPageState extends ConsumerState<StudioOnboardingPage> {
  final _salonNameController = TextEditingController();
  String _salonType = 'Yoga';

  final _memberTypeNameController = TextEditingController();
  String _memberTypeColor = _memberTypeColorHexes.first;
  String _memberTypeSessionType = 'group';
  bool _memberTypeCardBased = false;
  final _memberTypeCardFeeController = TextEditingController();

  final _paymentMethodNameController = TextEditingController();

  final _equipmentNameController = TextEditingController();
  String _equipmentType = 'Mat';
  int? _equipmentSalonId;

  bool _creatingResource = false;

  late final ProviderSubscription<StudioOnboardingState> _onboardingSub;

  @override
  void initState() {
    super.initState();
    _onboardingSub = ref.listenManual<StudioOnboardingState>(
      studioOnboardingProvider,
      (previous, next) {
        if (previous?.onboardingStep != next.onboardingStep) {
          _refreshResourcesForStep(next.onboardingStep);
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _onboardingSub.close();
    _salonNameController.dispose();
    _memberTypeNameController.dispose();
    _memberTypeCardFeeController.dispose();
    _paymentMethodNameController.dispose();
    _equipmentNameController.dispose();
    super.dispose();
  }

  String _formatTrialEndsAt(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _bootstrap() async {
    await ref.read(studioOnboardingProvider.notifier).fetchOnboardingStatus();
    if (!mounted) return;
    final step = ref.read(studioOnboardingProvider).onboardingStep;
    await _refreshResourcesForStep(step);
  }

  Future<void> _refreshResourcesForStep(String step) async {
    if (!mounted) return;

    switch (step) {
      case 'salon':
        await ref.read(salonsProvider.notifier).fetchSalons();
        break;
      case 'member_types':
        await ref
            .read(member_types.memberTypesProvider.notifier)
            .fetchMemberTypes();
        break;
      case 'payment_methods':
        await ref
            .read(payment_methods.paymentMethodsProvider.notifier)
            .fetchPaymentMethods();
        break;
      case 'equipment':
        await ref.read(salonsProvider.notifier).fetchSalons();
        await ref.read(equipmentProvider.notifier).fetchEquipment();
        break;
      default:
        break;
    }
  }

  String _tr(BuildContext context, String key, String fallback) {
    return AppLocalizations.of(context)?.translate(key) ?? fallback;
  }

  void _showError(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfo(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _advanceToStep(String nextStep) async {
    if (_creatingResource) return;

    final completeStepMessage = _tr(
      context,
      'completeStepBeforeContinuing',
      'Complete this step before continuing.',
    );
    final genericErrorMessage = _tr(context, 'error', 'Error');

    final result = await ref
        .read(studioOnboardingProvider.notifier)
        .advanceToStep(nextStep);

    if (result.success) {
      final latestState = ref.read(studioOnboardingProvider);
      if (latestState.onboardingCompleted &&
          latestState.onboardingStep == 'completed') {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage()),
          (route) => false,
        );
      }
      return;
    }

    if (result.shouldRefetch) {
      await ref.read(studioOnboardingProvider.notifier).fetchOnboardingStatus();
      if (!mounted) return;
      await _refreshResourcesForStep(
        ref.read(studioOnboardingProvider).onboardingStep,
      );
    }

    if (!mounted) return;
    if (result.requirementNotMet) {
      _showError(context, completeStepMessage);
      return;
    }

    _showError(context, result.userMessage ?? genericErrorMessage);
  }

  Future<void> _createSalon() async {
    final name = _salonNameController.text.trim();
    if (name.isEmpty) {
      _showError(context, _tr(context, 'required', 'Required'));
      return;
    }

    setState(() => _creatingResource = true);
    final notifier = ref.read(salonsProvider.notifier);
    await notifier.addSalon(Salon(id: 0, name: name, type: _salonType));
    await notifier.fetchSalons();
    if (!mounted) return;
    setState(() => _creatingResource = false);

    final err = ref.read(salonsProvider).error;
    if (err != null && err.trim().isNotEmpty) {
      _showError(context, err);
      return;
    }

    _salonNameController.clear();
    _showInfo(context, _tr(context, 'salonSaved', 'Salon saved'));
  }

  Future<void> _createMemberType() async {
    final name = _memberTypeNameController.text.trim();
    if (name.isEmpty) {
      _showError(context, _tr(context, 'required', 'Required'));
      return;
    }

    double fee = 0;
    if (_memberTypeCardBased) {
      final parsed = double.tryParse(_memberTypeCardFeeController.text.trim());
      if (parsed == null || parsed < 0) {
        _showError(context, _tr(context, 'required', 'Required'));
        return;
      }
      fee = parsed;
    }

    setState(() => _creatingResource = true);
    final notifier = ref.read(member_types.memberTypesProvider.notifier);
    await notifier.addMemberType(
      member_types.MemberType(
        id: '',
        name: name,
        color: _memberTypeColor,
        sessionType: _memberTypeSessionType,
        isCardBased: _memberTypeCardBased,
        cardUsageFee: _memberTypeCardBased ? fee : 0,
      ),
    );

    if (!mounted) return;
    setState(() => _creatingResource = false);
    final err = ref.read(member_types.memberTypesProvider).error;

    if (err != null && err.trim().isNotEmpty) {
      _showError(context, err);
      return;
    }

    _memberTypeNameController.clear();
    _memberTypeCardBased = false;
    _memberTypeCardFeeController.clear();
    _showInfo(context, _tr(context, 'save', 'Save'));
  }

  Future<void> _createPaymentMethod() async {
    final name = _paymentMethodNameController.text.trim();
    if (name.isEmpty) {
      _showError(context, _tr(context, 'required', 'Required'));
      return;
    }

    setState(() => _creatingResource = true);
    final notifier = ref.read(payment_methods.paymentMethodsProvider.notifier);
    await notifier.addPaymentMethod(
      payment_methods.PaymentMethod(id: '', name: name),
    );
    await notifier.fetchPaymentMethods();
    if (!mounted) return;
    setState(() => _creatingResource = false);

    final err = ref.read(payment_methods.paymentMethodsProvider).error;
    if (err != null && err.trim().isNotEmpty) {
      _showError(context, err);
      return;
    }

    _paymentMethodNameController.clear();
    _showInfo(context, _tr(context, 'save', 'Save'));
  }

  Future<void> _createEquipment() async {
    final name = _equipmentNameController.text.trim();
    if (name.isEmpty || _equipmentSalonId == null) {
      _showError(context, _tr(context, 'required', 'Required'));
      return;
    }

    final salons = ref.read(salonsProvider).salons;
    final selectedSalon = salons
        .where((e) => e.id == _equipmentSalonId)
        .toList();
    if (selectedSalon.isNotEmpty) {
      final salonType = selectedSalon.first.type;
      if ((salonType == 'Yoga' && _equipmentType != 'Mat') ||
          (salonType == 'Pilates' && _equipmentType != 'Reformer')) {
        _showError(
          context,
          'Invalid combination: $_equipmentType can only be assigned to $salonType salons.',
        );
        return;
      }
    }

    setState(() => _creatingResource = true);
    final notifier = ref.read(equipmentProvider.notifier);
    await notifier.addEquipment(
      Equipment(
        id: 0,
        name: name,
        type: _equipmentType,
        salonId: _equipmentSalonId!,
      ),
    );
    await notifier.fetchEquipment();
    if (!mounted) return;
    setState(() => _creatingResource = false);

    final err = ref.read(equipmentProvider).error;
    if (err != null && err.trim().isNotEmpty) {
      _showError(context, err);
      return;
    }

    _equipmentNameController.clear();
    _showInfo(context, _tr(context, 'save', 'Save'));
  }

  Widget _buildProgress(
    StudioOnboardingState onboardingState,
    BuildContext context,
  ) {
    final progressSteps = const [
      'studio',
      'salon',
      'member_types',
      'payment_methods',
      'equipment',
      'users',
    ];

    final labels = <String, String>{
      'studio': 'Studio',
      'salon': _tr(context, 'salonSetup', 'Salon'),
      'member_types': _tr(context, 'memberTypeSetup', 'Member Types'),
      'payment_methods': _tr(context, 'paymentMethodSetup', 'Payment Methods'),
      'equipment': _tr(context, 'equipmentSetup', 'Equipment'),
      'users': _tr(context, 'usersSetup', 'Users'),
    };

    final currentIndex = progressSteps.indexOf(onboardingState.onboardingStep);
    final normalizedIndex = currentIndex == -1 ? 0 : currentIndex;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(progressSteps.length, (index) {
        final step = progressSteps[index];
        final completed =
            onboardingState.onboardingCompleted || index < normalizedIndex;
        final current =
            !onboardingState.onboardingCompleted && index == normalizedIndex;

        final bg = completed
            ? kBrandAccentColor
            : current
            ? const Color(0xFFFFF3CD)
            : const Color(0xFFE9ECEF);
        final fg = completed
            ? Colors.white
            : current
            ? const Color(0xFF7A5D00)
            : const Color(0xFF6C757D);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${index + 1} ${labels[step] ?? step}',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStudioStep(BuildContext context, bool busy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.studioName,
          style: const TextStyle(
            color: kBrandTextColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _tr(context, 'yourStudioCode', 'Your Studio Code'),
          style: const TextStyle(
            color: kBrandTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          widget.studioCode,
          style: const TextStyle(
            color: kBrandTextColor,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _tr(
            context,
            'studioCodeTeamExplanation',
            'Share this code with your team. They will use it to log in.',
          ),
          style: const TextStyle(
            color: kBrandTextColor,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _tr(context, 'trialStarted', 'Your trial has started.'),
          style: const TextStyle(
            color: kBrandTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.trialEndsAt != null &&
            widget.trialEndsAt!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${_tr(context, 'trialEndsAt', 'Trial ends at')}: ${_formatTrialEndsAt(widget.trialEndsAt!.trim())}',
            style: const TextStyle(color: kBrandTextColor),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandAccentColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: busy ? null : () => _advanceToStep('salon'),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tr(context, 'continueSetup', 'Continue Setup')),
        ),
      ],
    );
  }

  Widget _buildResourceSummary({
    required BuildContext context,
    required bool satisfied,
    required String requirementKey,
    required String requirementFallback,
    required int count,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: satisfied ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        satisfied
            ? '${_tr(context, 'setupComplete', 'Setup complete')}: $count'
            : _tr(context, requirementKey, requirementFallback),
        style: const TextStyle(
          color: kBrandTextColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSalonStep(
    BuildContext context,
    StudioOnboardingState onboardingState,
  ) {
    final salonsState = ref.watch(salonsProvider);
    final hasSalon = salonsState.salons.isNotEmpty;
    final busy =
        onboardingState.advancing || _creatingResource || salonsState.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildResourceSummary(
          context: context,
          satisfied: hasSalon,
          requirementKey: 'atLeastOneSalon',
          requirementFallback: 'Create at least one salon.',
          count: salonsState.salons.length,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _salonNameController,
          decoration: InputDecoration(
            labelText: _tr(context, 'name', 'Name'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _salonType,
          decoration: InputDecoration(
            labelText: _tr(context, 'salonType', 'Salon Type'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'Yoga', child: Text('Yoga')),
            DropdownMenuItem(value: 'Pilates', child: Text('Pilates')),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _salonType = value);
                },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: busy ? null : _createSalon,
            child: Text(_tr(context, 'addSalon', 'Add Salon')),
          ),
        ),
        if (hasSalon) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: salonsState.salons
                .map(
                  (salon) => Chip(label: Text('${salon.name} (${salon.type})')),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandAccentColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: busy || !hasSalon
              ? null
              : () => _advanceToStep('member_types'),
          child: onboardingState.advancing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tr(context, 'continueSetup', 'Continue Setup')),
        ),
      ],
    );
  }

  Widget _buildMemberTypesStep(
    BuildContext context,
    StudioOnboardingState onboardingState,
  ) {
    final memberTypeState = ref.watch(member_types.memberTypesProvider);
    final hasMemberType = memberTypeState.memberTypes.isNotEmpty;
    final busy =
        onboardingState.advancing ||
        _creatingResource ||
        memberTypeState.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildResourceSummary(
          context: context,
          satisfied: hasMemberType,
          requirementKey: 'atLeastOneMemberType',
          requirementFallback: 'Create at least one member type.',
          count: memberTypeState.memberTypes.length,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _memberTypeNameController,
          decoration: InputDecoration(
            labelText: _tr(context, 'memberType', 'Member Type'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _memberTypeSessionType,
          decoration: InputDecoration(
            labelText: _tr(context, 'type', 'Type'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'group', child: Text('Group')),
            DropdownMenuItem(value: 'individual', child: Text('Individual')),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _memberTypeSessionType = value);
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _memberTypeColor,
          decoration: InputDecoration(
            labelText: _tr(context, 'color', 'Color'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _memberTypeColorHexes
              .map((hex) => DropdownMenuItem(value: hex, child: Text(hex)))
              .toList(),
          onChanged: busy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _memberTypeColor = value);
                },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Card-based membership'),
          value: _memberTypeCardBased,
          onChanged: busy
              ? null
              : (value) {
                  setState(() {
                    _memberTypeCardBased = value;
                    if (!value) {
                      _memberTypeCardFeeController.clear();
                    }
                  });
                },
        ),
        if (_memberTypeCardBased) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _memberTypeCardFeeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Card Usage Fee',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: busy ? null : _createMemberType,
            child: Text(_tr(context, 'add', 'Add')),
          ),
        ),
        if (hasMemberType) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: memberTypeState.memberTypes
                .map((item) => Chip(label: Text(item.name)))
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandAccentColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: busy || !hasMemberType
              ? null
              : () => _advanceToStep('payment_methods'),
          child: onboardingState.advancing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tr(context, 'continueSetup', 'Continue Setup')),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsStep(
    BuildContext context,
    StudioOnboardingState onboardingState,
  ) {
    final methodsState = ref.watch(payment_methods.paymentMethodsProvider);
    final hasMethod = methodsState.paymentMethods.isNotEmpty;
    final busy =
        onboardingState.advancing ||
        _creatingResource ||
        methodsState.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildResourceSummary(
          context: context,
          satisfied: hasMethod,
          requirementKey: 'atLeastOnePaymentMethod',
          requirementFallback: 'Create at least one payment method.',
          count: methodsState.paymentMethods.length,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _paymentMethodNameController,
          decoration: InputDecoration(
            labelText: _tr(context, 'paymentMethod', 'Payment Method'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: busy ? null : _createPaymentMethod,
            child: Text(_tr(context, 'addPaymentMethod', 'Add Payment Method')),
          ),
        ),
        if (hasMethod) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: methodsState.paymentMethods
                .map((method) => Chip(label: Text(method.name)))
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandAccentColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: busy || !hasMethod
              ? null
              : () => _advanceToStep('equipment'),
          child: onboardingState.advancing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tr(context, 'continueSetup', 'Continue Setup')),
        ),
      ],
    );
  }

  Widget _buildEquipmentStep(
    BuildContext context,
    StudioOnboardingState onboardingState,
  ) {
    final equipmentState = ref.watch(equipmentProvider);
    final salonsState = ref.watch(salonsProvider);
    final hasEquipment = equipmentState.equipmentList.isNotEmpty;
    final busy =
        onboardingState.advancing ||
        _creatingResource ||
        equipmentState.isLoading;

    final salons = salonsState.salons;
    final canCreate = salons.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildResourceSummary(
          context: context,
          satisfied: hasEquipment,
          requirementKey: 'atLeastOneEquipment',
          requirementFallback: 'Create at least one equipment record.',
          count: equipmentState.equipmentList.length,
        ),
        const SizedBox(height: 12),
        if (!canCreate)
          Text(
            _tr(context, 'atLeastOneSalon', 'Create at least one salon.'),
            style: const TextStyle(color: Colors.red),
          ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _equipmentNameController,
          decoration: InputDecoration(
            labelText: _tr(context, 'name', 'Name'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _equipmentType,
          decoration: InputDecoration(
            labelText: _tr(context, 'type', 'Type'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'Mat', child: Text('Mat')),
            DropdownMenuItem(value: 'Reformer', child: Text('Reformer')),
          ],
          onChanged: busy || !canCreate
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _equipmentType = value);
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _equipmentSalonId,
          decoration: InputDecoration(
            labelText: _tr(context, 'salon', 'Salon'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: salons
              .map(
                (salon) => DropdownMenuItem<int>(
                  value: salon.id,
                  child: Text('${salon.name} (${salon.type})'),
                ),
              )
              .toList(),
          onChanged: busy || !canCreate
              ? null
              : (value) {
                  setState(() => _equipmentSalonId = value);
                },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: busy || !canCreate ? null : _createEquipment,
            child: Text(_tr(context, 'add', 'Add')),
          ),
        ),
        if (hasEquipment) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: equipmentState.equipmentList
                .map((item) => Chip(label: Text(item.name)))
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandAccentColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: busy || !hasEquipment
              ? null
              : () => _advanceToStep('users'),
          child: onboardingState.advancing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tr(context, 'continueSetup', 'Continue Setup')),
        ),
      ],
    );
  }

  Widget _buildUsersStep(
    BuildContext context,
    StudioOnboardingState onboardingState,
  ) {
    final busy = onboardingState.advancing || _creatingResource;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr(
                  context,
                  'ownerAccountReady',
                  'Your owner account is ready. You can add instructors now or later from Settings.',
                ),
                style: const TextStyle(
                  color: kBrandTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _tr(
                  context,
                  'addLaterFromSettings',
                  'Yonetici hesabiniz hazir. Egitmenleri simdi veya daha sonra Ayarlar bolumunden ekleyebilirsiniz.',
                ),
                style: const TextStyle(color: kBrandTextColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandAccentColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: busy ? null : () => _advanceToStep('completed'),
          child: onboardingState.advancing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tr(context, 'finishSetup', 'Finish Setup')),
        ),
      ],
    );
  }

  Widget _buildCompletedStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _tr(context, 'setupComplete', 'Setup complete'),
          style: const TextStyle(
            color: kBrandTextColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandAccentColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainPage()),
              (route) => false,
            );
          },
          child: Text(_tr(context, 'continueSetup', 'Continue Setup')),
        ),
      ],
    );
  }

  Widget _buildCurrentStepCard(
    BuildContext context,
    StudioOnboardingState onboardingState,
  ) {
    final step = onboardingState.onboardingStep;

    switch (step) {
      case 'studio':
        return _buildStudioStep(context, onboardingState.advancing);
      case 'salon':
        return _buildSalonStep(context, onboardingState);
      case 'member_types':
        return _buildMemberTypesStep(context, onboardingState);
      case 'payment_methods':
        return _buildPaymentMethodsStep(context, onboardingState);
      case 'equipment':
        return _buildEquipmentStep(context, onboardingState);
      case 'users':
        return _buildUsersStep(context, onboardingState);
      case 'completed':
        return _buildCompletedStep(context);
      default:
        return _buildStudioStep(context, onboardingState.advancing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(studioOnboardingProvider);

    final firstLoadFailed =
        onboardingState.error != null &&
        onboardingState.error!.trim().isNotEmpty &&
        onboardingState.studioId == null;

    return Scaffold(
      backgroundColor: kBrandBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _tr(context, 'setupYourStudio', 'Setup your studio'),
          style: const TextStyle(color: kBrandTextColor),
        ),
        backgroundColor: kBrandBackgroundColor,
        iconTheme: const IconThemeData(color: kBrandTextColor),
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentMaxWidth = constraints.maxWidth >= 700 ? 640.0 : 560.0;

            if (onboardingState.loading && onboardingState.studioId == null) {
              return const Center(
                child: CircularProgressIndicator(color: kBrandTextColor),
              );
            }

            if (firstLoadFailed) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            onboardingState.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBrandAccentColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _bootstrap(),
                            child: Text(_tr(context, 'retry', 'Retry')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tr(context, 'setupProgress', 'Setup progress'),
                              style: const TextStyle(
                                color: kBrandTextColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildProgress(onboardingState, context),
                          ],
                        ),
                      ),
                      if (onboardingState.error != null &&
                          onboardingState.error!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            onboardingState.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _buildCurrentStepCard(context, onboardingState),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
