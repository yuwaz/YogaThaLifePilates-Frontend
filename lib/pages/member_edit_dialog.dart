import '../providers/instructors_provider.dart';
import '../models/instructor.dart' as instructor_model;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/member.dart';
// import '../providers/equipment_provider.dart';
import '../providers/salons_provider.dart';
import '../providers/member_types_provider.dart';
import '../theme/app_design_tokens.dart';

typedef MemberEditOnSave =
    Future<String?> Function(
      String name,
      String phone,
      String email,
      int memberTypeId,
      List<int> assignedSalonIds,
      List<int> assignedEquipmentIds,
      int remainingLessons,
      int? assignedInstructorId,
    );

class MemberEditDialog extends ConsumerStatefulWidget {
  final Member? member;
  final String token;
  final MemberEditOnSave onSave;

  const MemberEditDialog({
    Key? key,
    this.member,
    required this.token,
    required this.onSave,
  }) : super(key: key);

  @override
  ConsumerState<MemberEditDialog> createState() => _MemberEditDialogState();
}

class _MemberEditDialogState extends ConsumerState<MemberEditDialog> {
  bool _fetchedInstructors = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetchedInstructors) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final instructorsState = ref.read(instructorsProvider);
        final instructorsNotifier = ref.read(instructorsProvider.notifier);
        if (!instructorsState.isLoading &&
            instructorsState.instructors.isEmpty) {
          instructorsNotifier.fetchInstructors();
        }
      });
      _fetchedInstructors = true;
    }
  }

  String? _assignedInstructorId;
  bool _isSubmitting = false;
  String? _backendError;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  int _memberTypeId = 1;
  List<int> _selectedSalonIds = [];
  // Removed equipment selection: List<int> _selectedEquipmentIds = [];

  @override
  void initState() {
    super.initState();
    debugPrint('[MemberEditDialog] initState: member = \\${widget.member}');
    _nameController = TextEditingController(text: widget.member?.name ?? '');
    // If editing and phone starts with '+90', strip it for input
    String phone = widget.member?.phone ?? '';
    if (phone.startsWith('+90')) {
      phone = phone.substring(3);
    }
    _phoneController = TextEditingController(text: phone);
    _emailController = TextEditingController(text: widget.member?.email ?? '');
    _memberTypeId = widget.member?.memberTypeId ?? 1;
    _selectedSalonIds = widget.member != null
        ? List<int>.from(widget.member!.assignedSalonIds)
        : [];
    _assignedInstructorId = widget.member?.assignedInstructorId?.toString();
    // Removed equipment selection init
  }

  @override
  Widget build(BuildContext context) {
    final instructorsState = ref.watch(instructorsProvider);
    // Deduplicate instructors by id
    final List<instructor_model.Instructor> instructors = {
      for (var inst in instructorsState.instructors) inst.id: inst,
    }.values.toList();
    debugPrint('[MemberEditDialog] build called');
    final salonsState = ref.watch(salonsProvider);
    final salons = salonsState.salons;
    // Removed equipment provider usage
    final l10n = AppLocalizations.of(context);
    final memberTypesState = ref.watch(memberTypesProvider);
    final memberTypes = memberTypesState.memberTypes;
    debugPrint(
      '[MemberEditDialog] memberTypes: \\${memberTypes.map((e) => e.name).toList()}',
    );
    return AlertDialog(
      backgroundColor: AppDesignTokens.surface,
      title: Text(
        widget.member == null
            ? (l10n?.translate('addMember') ?? 'Add Member')
            : (l10n?.translate('editMember') ?? 'Edit Member'),
        style: AppTypography.sectionTitle,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n?.translate('name') ?? 'Name',
                  labelStyle: AppTypography.label,
                ),
                enabled: !_isSubmitting,
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return l10n?.translate('nameRequired') ??
                        'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: l10n?.translate('phone') ?? 'Phone',
                  labelStyle: AppTypography.label,
                  prefixText: '+90 ',
                ),
                keyboardType: TextInputType.phone,
                enabled: !_isSubmitting,
                validator: (value) {
                  final phone = value?.trim() ?? '';

                  if (phone.isEmpty) {
                    return 'Telefon numarası zorunlu';
                  }

                  if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
                    return 'Geçerli bir telefon numarası girin';
                  }

                  if (phone.length != 10) {
                    return 'Telefon numarası 10 haneli olmalı';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: l10n?.translate('email') ?? 'Email',
                  labelStyle: AppTypography.label,
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isSubmitting,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null; // Email is optional
                  }
                  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailPattern.hasMatch(value.trim())) {
                    return l10n?.translate('invalidEmail') ??
                        'Invalid email format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n?.translate('assignSalons') ?? 'Assign Salons',
                style: AppTypography.bodyStrong,
              ),
              const SizedBox(height: 8),
              if (salonsState.isLoading)
                const CircularProgressIndicator()
              else if (salonsState.error != null)
                Text(
                  l10n?.translate('errorLoadingSalons') ??
                      'Error loading salons',
                )
              else if (salons.isEmpty)
                Text(
                  l10n?.translate('noSalonsAvailable') ?? 'No salons available',
                )
              else
                Wrap(
                  spacing: 8,
                  children: salons
                      .map<Widget>(
                        (salon) => FilterChip(
                          label: Text(salon.name),
                          selected: _selectedSalonIds.contains(salon.id),
                          onSelected: !_isSubmitting
                              ? (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSalonIds.add(salon.id);
                                    } else {
                                      _selectedSalonIds.remove(salon.id);
                                    }
                                  });
                                }
                              : null,
                          selectedColor: AppDesignTokens.selectedBackground,
                        ),
                      )
                      .toList(),
                ),
              // Removed equipment selection UI
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // Only set value if the id exists exactly once in deduped list
                value:
                    (instructors
                            .where((inst) => inst.id == _assignedInstructorId)
                            .length ==
                        1)
                    ? _assignedInstructorId
                    : null,
                decoration: InputDecoration(
                  labelText: l10n?.translate('instructor') ?? 'Eğitmen',
                  labelStyle: AppTypography.label,
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(l10n?.translate('noInstructor') ?? '-'),
                  ),
                  ...instructors.map(
                    (instructor_model.Instructor inst) =>
                        DropdownMenuItem<String>(
                          value: inst.id,
                          child: Text(inst.username),
                        ),
                  ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _assignedInstructorId = value;
                        });
                      },
                isExpanded: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value:
                    memberTypes.any(
                      (type) =>
                          int.tryParse(type.id.toString()) == _memberTypeId,
                    )
                    ? _memberTypeId
                    : (memberTypes.isNotEmpty
                          ? int.tryParse(memberTypes.first.id.toString())
                          : null),
                decoration: InputDecoration(
                  labelText: l10n?.translate('memberType') ?? 'Member Type',
                  labelStyle: AppTypography.label,
                ),
                items: memberTypes
                    .map<DropdownMenuItem<int>>(
                      (type) => DropdownMenuItem<int>(
                        value: int.tryParse(type.id.toString()),
                        child: Text(type.name),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        debugPrint(
                          '[MemberEditDialog] memberType changed: \\${value}',
                        );
                        if (value != null) {
                          setState(() {
                            _memberTypeId = value;
                          });
                        }
                      },
                validator: (value) {
                  debugPrint(
                    '[MemberEditDialog] memberType validator: \\${value}',
                  );
                  if (value == null) {
                    return l10n?.translate('memberTypeRequired') ??
                        'Member type is required';
                  }
                  return null;
                },
              ),
              if (_backendError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _backendError!,
                  style: AppTypography.body.copyWith(
                    color: AppDesignTokens.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          style: AppButtonStyles.secondary,
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: const Icon(AppIcons.close, size: 18),
          label: Text(l10n?.translate('cancel') ?? 'İptal'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: AppButtonStyles.primary,
          onPressed: _isSubmitting
              ? null
              : () async {
                  debugPrint('[MemberEditDialog] submit pressed');
                  setState(() {
                    _isSubmitting = true;
                  });
                  if (!_formKey.currentState!.validate()) {
                    debugPrint('[MemberEditDialog] form validation failed');
                    setState(() => _isSubmitting = false);
                    return;
                  }
                  if (_selectedSalonIds.isEmpty) {
                    debugPrint('[MemberEditDialog] no salon selected');
                    setState(() {
                      _isSubmitting = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n?.translate('selectAtLeastOneSalon') ??
                              'Lütfen en az bir salon seçin',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  debugPrint('[MemberEditDialog] calling onSave');
                  final fullPhone = '+90' + _phoneController.text.trim();
                  final result = await widget.onSave(
                    _nameController.text.trim(),
                    fullPhone,
                    _emailController.text.trim(),
                    _memberTypeId,
                    _selectedSalonIds,
                    [], // No equipment
                    0,
                    _assignedInstructorId != null &&
                            _assignedInstructorId!.isNotEmpty
                        ? int.tryParse(_assignedInstructorId!)
                        : null,
                  );
                  debugPrint('[MemberEditDialog] onSave result: \\${result}');
                  if (result != null && result.isNotEmpty) {
                    setState(() {
                      _backendError = result;
                      _isSubmitting = false;
                    });
                  } else {
                    Navigator.pop(context, true);
                  }
                },
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(AppIcons.save, size: 18),
          label: _isSubmitting
              ? const Text('')
              : Text(
                  widget.member == null
                      ? (l10n?.translate('submit') ?? 'Kaydet')
                      : (l10n?.translate('save') ?? 'Kaydet'),
                ),
        ),
      ],
    );
  }
}
