import 'dart:convert';

import '../l10n/app_localizations.dart';
import '../models/lesson_package.dart' as model_lesson;
import '../providers/lesson_packages_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/payment_methods_provider.dart' as payment_methods;
import '../providers/member_types_provider.dart' as member_types;
import '../models/salon.dart';
import '../models/equipment.dart';
import '../models/instructor.dart' as model;
import '../providers/salons_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/instructors_provider.dart' show instructorsProvider;
import '../providers/locale_provider.dart';
import '../widgets/logout_button.dart';
import '../widgets/subscription_settings_section.dart';
import '../theme/app_design_tokens.dart';

// Predefined member type colors (must match requirements)
const List<Color> kMemberTypeColors = [
  Color(0xFFF08080),
  Color(0xFFF0A09F),
  Color(0xFFDEE0C2),
  Color(0xFFB7DF9C),
  Color(0xFF8CD6BA),
  Color(0xFF83A8C3),
];
const List<String> kMemberTypeColorHexes = [
  "#F08080",
  "#F0A09F",
  "#DEE0C2",
  "#B7DF9C",
  "#8CD6BA",
  "#83A8C3",
];

bool canManageBillingSettings(AuthState auth) {
  return (auth.role ?? '').trim() == 'admin';
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);
    final role = auth.role ?? '';
    final permissions = auth.permissions;
    final canManageSettings =
        role == 'admin' || permissions.contains('settings');
    final canManageBilling = canManageBillingSettings(auth);

    final tabs = <Tab>[
      const Tab(text: 'Hesabım'),
      const Tab(text: 'Şifre Değiştir'),
    ];
    final tabViews = <Widget>[
      const _AccountSection(),
      const _ChangePasswordSection(),
    ];

    if (canManageBilling) {
      tabs.add(Tab(text: loc?.translate('subscriptionTab') ?? 'Subscription'));
      tabViews.add(const SubscriptionSettingsSection());
    }

    if (canManageSettings) {
      tabs.addAll([
        Tab(text: loc?.translate('instructors') ?? 'Instructors'),
        Tab(text: loc?.translate('lessonPackages') ?? 'Lesson Packages'),
        Tab(text: loc?.translate('memberType') ?? 'Member Types'),
        Tab(text: loc?.translate('paymentMethods') ?? 'Payment Methods'),
        Tab(text: loc?.translate('salon') ?? 'Salons'),
        Tab(text: loc?.translate('equipment') ?? 'Equipment'),
      ]);

      tabViews.addAll([
        const _InstructorsSection(),
        const _LessonPackagesSection(),
        _MemberTypesSection(),
        const _PaymentMethodsSection(),
        const _SalonsSection(),
        const _EquipmentSection(),
      ]);
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppDesignTokens.backgroundPrimary,
        appBar: AppBar(
          toolbarHeight: 46,
          backgroundColor: AppDesignTokens.surface,
          foregroundColor: AppDesignTokens.textPrimary,
          iconTheme: const IconThemeData(color: AppDesignTokens.textPrimary),
          title: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              loc?.translate('settings') ?? 'Settings',
              style: AppTypography.sectionTitle,
              textAlign: TextAlign.left,
            ),
          ),
          actions: [
            IconButton(
              style: AppButtonStyles.compactIcon,
              icon: const Icon(Icons.language),
              tooltip: loc?.translate('language') ?? 'Language',
              onPressed: () async {
                final selected = await showDialog<Locale>(
                  context: context,
                  builder: (context) => SimpleDialog(
                    backgroundColor: AppDesignTokens.surface,
                    title: Text(
                      loc?.translate('language') ?? 'Language',
                      style: AppTypography.sectionTitle,
                    ),
                    children: [
                      SimpleDialogOption(
                        onPressed: () =>
                            Navigator.pop(context, const Locale('en')),
                        child: Text(
                          loc?.translate('english') ?? 'English',
                          style: AppTypography.body,
                        ),
                      ),
                      SimpleDialogOption(
                        onPressed: () =>
                            Navigator.pop(context, const Locale('tr')),
                        child: Text(
                          loc?.translate('turkish') ?? 'Türkçe',
                          style: AppTypography.body,
                        ),
                      ),
                    ],
                  ),
                );
                if (selected != null) {
                  await ref.read(localeProvider.notifier).setLocale(selected);
                }
              },
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: LogoutButton(),
            ),
          ],
          elevation: 0,
        ),
        body: Column(
          children: [
            Material(
              color: AppDesignTokens.surface,
              child: TabBar(
                isScrollable: true,
                labelColor: AppDesignTokens.textPrimary,
                unselectedLabelColor: AppDesignTokens.textSecondary,
                indicatorColor: AppDesignTokens.primaryAction,
                labelStyle: AppTypography.label,
                unselectedLabelStyle: AppTypography.label,
                tabs: tabs,
              ),
            ),
            Expanded(child: TabBarView(children: tabViews)),
          ],
        ),
      ),
    );
  }
}

class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final token = ref.read(authProvider).token;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Kullanıcı bilgisi alınamadı';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _profile = decoded;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Kullanıcı bilgisi alınamadı';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Kullanıcı bilgisi alınamadı';
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Kullanıcı bilgisi alınamadı';
        _isLoading = false;
      });
    }
  }

  String _formatRole(String rawRole) {
    if (rawRole == 'admin') return 'Yönetici';
    if (rawRole == 'instructor') return 'Eğitmen';
    return rawRole;
  }

  String _formatAssignedSalonNames(dynamic value, List<Salon> salons) {
    if (value is! List || value.isEmpty) return '-';

    final salonById = {for (final salon in salons) salon.id: salon.name};
    final names = value.map((id) {
      final parsedId = id is int ? id : int.tryParse(id.toString());
      if (parsedId == null) return 'Salon ID $id';
      return salonById[parsedId] ?? 'Salon ID $parsedId';
    }).toList();

    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final salons = ref.watch(salonsProvider).salons;
    final username = _profile?['username']?.toString() ?? '-';
    final rawRole = _profile?['role']?.toString() ?? '-';
    final role = _formatRole(rawRole);
    final assignedSalonNames = _formatAssignedSalonNames(
      _profile?['assignedSalonIds'],
      salons,
    );

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: AppTypography.body.copyWith(color: AppDesignTokens.error),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: AppButtonStyles.secondary,
              onPressed: _fetchProfile,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppDesignTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppDesignTokens.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hesabım', style: AppTypography.sectionTitle),
                  const SizedBox(height: 12),
                  Text('Kullanıcı Adı: $username', style: AppTypography.body),
                  const SizedBox(height: 8),
                  Text('Rol: $role', style: AppTypography.body),
                  const SizedBox(height: 8),
                  Text(
                    'Atanan Salonlar: $assignedSalonNames',
                    style: AppTypography.body,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordSection extends ConsumerStatefulWidget {
  const _ChangePasswordSection();

  @override
  ConsumerState<_ChangePasswordSection> createState() =>
      _ChangePasswordSectionState();
}

class _ChangePasswordSectionState
    extends ConsumerState<_ChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final token = ref.read(authProvider).token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Şifre güncellenemedi')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/auth/me/password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'oldPassword': _oldPasswordController.text.trim(),
          'newPassword': _newPasswordController.text.trim(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifre başarıyla güncellendi')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Şifre güncellenemedi')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Şifre güncellenemedi')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Şifre Değiştir', style: AppTypography.sectionTitle),
            const SizedBox(height: 16),
            TextFormField(
              controller: _oldPasswordController,
              obscureText: true,
              decoration: _settingsInputDecoration('Mevcut Şifre'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bu alan zorunludur';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: _settingsInputDecoration('Yeni Şifre'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bu alan zorunludur';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: _settingsInputDecoration('Yeni Şifre Tekrar'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bu alan zorunludur';
                }
                if (value.trim() != _newPasswordController.text.trim()) {
                  return 'Yeni şifreler eşleşmiyor';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppButtonStyles.primary,
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Güncelle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _settingsInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: AppTypography.label,
    filled: true,
    fillColor: AppDesignTokens.backgroundSecondary,
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: AppDesignTokens.border),
    ),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppDesignTokens.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppDesignTokens.textPrimary),
    ),
  );
}

// Section classes moved to top-level (outside SettingsPage)
// ---
// class ends here

// The following are minimal placeholder widgets for each section.
// Replace with your actual implementations as needed.

class _InstructorsSection extends ConsumerWidget {
  const _InstructorsSection();

  String _formatFee(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instructorsState = ref.watch(instructorsProvider);
    final instructorsNotifier = ref.read(instructorsProvider.notifier);
    final salonsState = ref.watch(salonsProvider);

    // Only run fetchInstructors after first build, once per widget lifecycle
    // ignore: use_build_context_synchronously
    if (!instructorsState.isLoading && instructorsState.instructors.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (instructorsNotifier.mounted &&
            ref.read(instructorsProvider).instructors.isEmpty &&
            !ref.read(instructorsProvider).isLoading) {
          instructorsNotifier.fetchInstructors();
        }
      });
    }

    return Stack(
      children: [
        Column(
          children: [
            if (instructorsState.isLoading) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => instructorsNotifier.fetchInstructors(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: instructorsState.instructors.length,
                  itemBuilder: (context, index) {
                    final instructor = instructorsState.instructors[index];
                    print(
                      '[SettingsPage] instructor.permissions for \\${instructor.username}: \\${instructor.permissions}',
                    );
                    final assignedSalons = salonsState.salons
                        .where(
                          (s) => instructor.assignedSalonIds.contains(s.id),
                        )
                        .map((s) => s.name)
                        .join(', ');
                    return Card(
                      color: AppDesignTokens.surface,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppDesignTokens.border),
                      ),
                      child: ListTile(
                        title: Text(
                          instructor.username,
                          style: AppTypography.cardTitle,
                        ),
                        subtitle: Text(
                          'Salonlar: $assignedSalons\nGrup: ${_formatFee(instructor.groupSessionFee)} | Bireysel: ${_formatFee(instructor.individualSessionFee)}',
                          style: AppTypography.caption,
                        ),
                        isThreeLine: false,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              style: AppButtonStyles.compactIcon,
                              icon: const Icon(AppIcons.edit),
                              onPressed: () {
                                _showInstructorDialog(
                                  context,
                                  ref,
                                  salonsState.salons,
                                  instructor: instructor,
                                );
                              },
                            ),
                            IconButton(
                              color: AppDesignTokens.destructive,
                              icon: const Icon(AppIcons.delete),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: AppDesignTokens.surface,
                                    title: const Text(
                                      'Delete Instructor',
                                      style: AppTypography.sectionTitle,
                                    ),
                                    content: const Text(
                                      'Are you sure you want to delete this instructor?',
                                      style: AppTypography.body,
                                    ),
                                    actions: [
                                      OutlinedButton.icon(
                                        style: AppButtonStyles.secondary,
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        icon: const Icon(
                                          AppIcons.close,
                                          size: 18,
                                        ),
                                        label: const Text('Cancel'),
                                      ),
                                      ElevatedButton.icon(
                                        style: AppButtonStyles.destructive,
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        icon: const Icon(
                                          AppIcons.delete,
                                          size: 18,
                                        ),
                                        label: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  final token = await ref
                                      .read(instructorsProvider.notifier)
                                      .getToken();
                                  if (token == null) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('No auth token found.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  await ref
                                      .read(instructorsProvider.notifier)
                                      .deleteInstructor(token, instructor.id);
                                  final err = ref
                                      .read(instructorsProvider)
                                      .error;
                                  if (err == null) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Instructor deleted successfully',
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $err'),
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
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: AppDesignTokens.primaryAction,
            foregroundColor: AppDesignTokens.primaryActionForeground,
            key: const ValueKey('addInstructorFab'),
            onPressed: () =>
                _showInstructorDialog(context, ref, salonsState.salons),
            child: const Icon(AppIcons.create),
            tooltip: 'Eğitmen Ekle',
          ),
        ),
      ],
    );
  }
}

const List<Map<String, String>> kInstructorPermissionOptions = [
  {'key': 'members', 'label': 'Üyeler'},
  {'key': 'reservations', 'label': 'Rezervasyonlar'},
  {'key': 'payments', 'label': 'Ödemeler'},
  {'key': 'attendances', 'label': 'Yoklamalar'},
  {'key': 'reports', 'label': 'Raporlar'},
  {'key': 'settings', 'label': 'Ayarlar'},
];

// Helper for Turkish label to key normalization
String? permissionLabelToKey(String label) {
  for (final opt in kInstructorPermissionOptions) {
    if (opt['label'] == label) return opt['key'];
  }
  return null;
}

final Set<String> kValidPermissionKeys = {
  'members',
  'reservations',
  'payments',
  'attendances',
  'reports',
  'settings',
};

void _showInstructorDialog(
  BuildContext context,
  WidgetRef ref,
  List<Salon> salons, {
  model.Instructor? instructor,
}) {
  final formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController(
    text: instructor?.username ?? '',
  );
  final passwordController = TextEditingController();
  final groupSessionFeeController = TextEditingController(
    text: (instructor != null && instructor.groupSessionFee > 0)
        ? instructor.groupSessionFee.toString()
        : '',
  );
  final individualSessionFeeController = TextEditingController(
    text: (instructor != null && instructor.individualSessionFee > 0)
        ? instructor.individualSessionFee.toString()
        : '',
  );
  List<int> selectedSalonIds = List<int>.from(
    instructor?.assignedSalonIds ?? [],
  );
  // Normalize any Turkish label to key for old instructors
  List<String> permissions = List<String>.from(instructor?.permissions ?? []);
  permissions = permissions
      .map(
        (p) => kValidPermissionKeys.contains(p)
            ? p
            : (permissionLabelToKey(p) ?? p),
      )
      .toList();
  final isEdit = instructor != null;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppDesignTokens.surface,
        title: Text(
          isEdit ? 'Eğitmeni Düzenle' : 'Eğitmen Ekle',
          style: AppTypography.sectionTitle,
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameController,
                  decoration: _settingsInputDecoration('Kullanıcı Adı'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter username' : null,
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: _settingsInputDecoration('Şifre'),
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter password' : null,
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: groupSessionFeeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _settingsInputDecoration('Grup Seans Ücreti'),
                  validator: (v) {
                    final input = v?.trim() ?? '';
                    if (input.isEmpty) return null;
                    final fee = double.tryParse(input);
                    if (fee == null) return 'Geçerli bir sayı girin';
                    if (fee < 0) return 'Negatif olamaz';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: individualSessionFeeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _settingsInputDecoration('Bireysel Seans Ücreti'),
                  validator: (v) {
                    final input = v?.trim() ?? '';
                    if (input.isEmpty) return null;
                    final fee = double.tryParse(input);
                    if (fee == null) return 'Geçerli bir sayı girin';
                    if (fee < 0) return 'Negatif olamaz';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Atanan Salonlar',
                    style: AppTypography.bodyStrong,
                  ),
                ),
                ...salons.map(
                  (salon) => CheckboxListTile(
                    value: selectedSalonIds.contains(salon.id),
                    title: Text(
                      '${salon.name} (${salon.type})',
                      style: AppTypography.body,
                    ),
                    onChanged: (checked) {
                      if (checked == true) {
                        if (!selectedSalonIds.contains(salon.id))
                          selectedSalonIds.add(salon.id);
                      } else {
                        selectedSalonIds.remove(salon.id);
                      }
                      // Force rebuild
                      (context as Element).markNeedsBuild();
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Yetkiler', style: AppTypography.bodyStrong),
                ),
                ...kInstructorPermissionOptions.map(
                  (opt) => CheckboxListTile(
                    value: permissions.contains(opt['key']),
                    title: Text(
                      opt['label'] ?? opt['key']!,
                      style: AppTypography.body,
                    ),
                    onChanged: (checked) {
                      final key = opt['key']!;
                      if (checked == true) {
                        if (!permissions.contains(key)) permissions.add(key);
                      } else {
                        permissions.remove(key);
                      }
                      (context as Element).markNeedsBuild();
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            style: AppButtonStyles.secondary,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(AppIcons.close, size: 18),
            label: const Text('İptal'),
          ),
          ElevatedButton.icon(
            style: AppButtonStyles.primary,
            onPressed: () async {
              try {
                if (!formKey.currentState!.validate()) return;
                if (selectedSalonIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select at least one salon')),
                  );
                  return;
                }
                if (permissions.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('En az bir yetki seçin')),
                  );
                  return;
                }
                final instructorsNotifier = ref.read(
                  instructorsProvider.notifier,
                );
                // Deduplicate and filter permissions to only valid keys
                final normalizedPermissions = permissions
                    .map(
                      (p) => kValidPermissionKeys.contains(p)
                          ? p
                          : (permissionLabelToKey(p) ?? p),
                    )
                    .where((p) => kValidPermissionKeys.contains(p))
                    .toSet()
                    .toList();
                print(
                  '[Instructor] normalized selected permission keys: $normalizedPermissions',
                );
                final groupSessionFee =
                    double.tryParse(groupSessionFeeController.text.trim()) ?? 0;
                final individualSessionFee =
                    double.tryParse(
                      individualSessionFeeController.text.trim(),
                    ) ??
                    0;
                final newInstructor = model.Instructor(
                  id: isEdit ? instructor.id : '',
                  username: usernameController.text.trim(),
                  password: passwordController.text.trim(),
                  assignedSalonIds: selectedSalonIds,
                  permissions: normalizedPermissions,
                  groupSessionFee: groupSessionFee,
                  individualSessionFee: individualSessionFee,
                );
                if (isEdit) {
                  await instructorsNotifier.updateInstructor(newInstructor);
                } else {
                  await instructorsNotifier.addInstructor(newInstructor);
                }
                final err = ref.read(instructorsProvider).error;
                // Log backend response body runtime types
                final resp = ref.read(instructorsProvider).instructors;
                print(
                  'Instructor backend response type: ' +
                      resp.runtimeType.toString(),
                );
                for (var i = 0; i < resp.length; i++) {
                  print(
                    'Instructor backend response[' +
                        i.toString() +
                        '] type: ' +
                        resp[i].runtimeType.toString(),
                  );
                }
                if (err == null) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? 'Instructor updated successfully'
                              : 'Instructor added successfully',
                        ),
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err), backgroundColor: Colors.red),
                    );
                  }
                }
              } catch (e, stack) {
                print('EXCEPTION in Instructor create: ' + e.toString());
                print('STACKTRACE in Instructor create: ' + stack.toString());
                print('FILE: settings_page.dart (Instructor create)');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Exception: ' + e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(AppIcons.save, size: 18),
            label: Text(isEdit ? 'Kaydet' : 'Ekle'),
          ),
        ],
      );
    },
  );
}

class _LessonPackagesSection extends ConsumerWidget {
  const _LessonPackagesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonPackagesState = ref.watch(lessonPackagesProvider);
    final lessonPackagesNotifier = ref.read(lessonPackagesProvider.notifier);

    return Stack(
      children: [
        Column(
          children: [
            if (lessonPackagesState.isLoading) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    lessonPackagesNotifier.fetchLessonPackages(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: lessonPackagesState.lessonPackages.length,
                  itemBuilder: (context, index) {
                    final pkg = lessonPackagesState.lessonPackages[index];
                    return ListTile(
                      title: Text(pkg.name),
                      subtitle: Text('Ders: ${pkg.lessonCount}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₺${pkg.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              _showLessonPackageDialog(context, ref, pkg: pkg);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Sil'),
                                  content: const Text(
                                    'Silmek istediğinize emin misiniz?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('İptal'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Sil'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              print("DELETE TRIGGERED ID: ${pkg.id}");
                              final token = await ref
                                  .read(lessonPackagesProvider.notifier)
                                  .getToken();
                              if (token == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('No auth token found.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                return;
                              }
                              await ref
                                  .read(lessonPackagesProvider.notifier)
                                  .deleteLessonPackage(token, pkg.id);
                              final err = ref
                                  .read(lessonPackagesProvider)
                                  .error;
                              if (err == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Lesson package deleted successfully',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $err'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            key: const ValueKey('addLessonPackageFab'),
            onPressed: () => _showLessonPackageDialog(context, ref),
            child: const Icon(Icons.add),
            tooltip: 'Ders Paketi Ekle',
          ),
        ),
      ],
    );
  }
}

void _showLessonPackageDialog(
  BuildContext context,
  WidgetRef ref, {
  model_lesson.LessonPackage? pkg,
}) {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: pkg?.name ?? '');
  final lessonCountController = TextEditingController(
    text: pkg?.lessonCount.toString() ?? '',
  );
  final priceController = TextEditingController(
    text: pkg != null ? pkg.price.toStringAsFixed(2) : '',
  );
  final isEdit = pkg != null;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(isEdit ? 'Ders Paketini Düzenle' : 'Ders Paketi Ekle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'İsim'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: lessonCountController,
                decoration: const InputDecoration(labelText: 'Ders Sayısı'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a valid lesson count';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Fiyat',
                  prefixText: '₺',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  final d = double.tryParse(v?.replaceAll(',', '.') ?? '');
                  if (d == null || d < 0) return 'Enter a valid price';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (!formKey.currentState!.validate()) return;
                final lessonPackagesNotifier = ref.read(
                  lessonPackagesProvider.notifier,
                );
                final lessonCountVal = int.parse(
                  lessonCountController.text.trim(),
                );
                final priceVal = int.parse(
                  priceController.text
                      .trim()
                      .replaceAll('₺', '')
                      .replaceAll(',', '')
                      .split('.')
                      .first,
                );
                // Debug: print runtime types for all request body fields
                print(
                  'LessonPackage.name runtimeType: ' +
                      nameController.text.trim().runtimeType.toString(),
                );
                print(
                  'LessonPackage.lessonCount runtimeType: ' +
                      lessonCountVal.runtimeType.toString(),
                );
                print(
                  'LessonPackage.price runtimeType: ' +
                      priceVal.runtimeType.toString(),
                );
                final newPkg = model_lesson.LessonPackage(
                  id: isEdit ? pkg.id : '',
                  name: nameController.text.trim(),
                  lessonCount: lessonCountVal,
                  price: priceVal,
                );
                print(
                  'LessonPackage dialog final request body: ' +
                      newPkg.toJson().toString(),
                );
                if (isEdit) {
                  await lessonPackagesNotifier.updateLessonPackage(newPkg);
                } else {
                  await lessonPackagesNotifier.addLessonPackage(newPkg);
                }
                // Wait for provider to finish loading and list to refresh
                while (ref.read(lessonPackagesProvider).isLoading) {
                  await Future.delayed(const Duration(milliseconds: 50));
                }
                // Log backend response body runtime types
                final resp = ref.read(lessonPackagesProvider).lessonPackages;
                print(
                  'LessonPackage backend response type: ' +
                      resp.runtimeType.toString(),
                );
                for (var i = 0; i < resp.length; i++) {
                  print(
                    'LessonPackage backend response[' +
                        i.toString() +
                        '] type: ' +
                        resp[i].runtimeType.toString(),
                  );
                }
                final err = ref.read(lessonPackagesProvider).error;
                if (err == null) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? 'Lesson package updated successfully'
                              : 'Lesson package added successfully',
                        ),
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err), backgroundColor: Colors.red),
                    );
                  }
                }
              } catch (e, stack) {
                print('EXCEPTION in LessonPackage create: ' + e.toString());
                print(
                  'STACKTRACE in LessonPackage create: ' + stack.toString(),
                );
                print('FILE: settings_page.dart (LessonPackage create)');
                print('FINAL request body:');
                print('  name: ' + nameController.text.trim().toString());
                int? lessonCountVal;
                int? priceVal;
                try {
                  lessonCountVal = int.tryParse(
                    lessonCountController.text.trim(),
                  );
                } catch (_) {}
                try {
                  priceVal = int.tryParse(
                    priceController.text
                        .trim()
                        .replaceAll('₺', '')
                        .replaceAll(',', '')
                        .split('.')
                        .first,
                  );
                } catch (_) {}
                print(
                  '  lessonCount: ' +
                      (lessonCountVal?.toString() ?? 'null') +
                      ' type: ' +
                      (lessonCountVal?.runtimeType.toString() ?? 'null'),
                );
                print(
                  '  price: ' +
                      (priceVal?.toString() ?? 'null') +
                      ' type: ' +
                      (priceVal?.runtimeType.toString() ?? 'null'),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Exception: ' + e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Kaydet' : 'Ekle'),
          ),
        ],
      );
    },
  );
}

class _MemberTypesSection extends ConsumerWidget {
  const _MemberTypesSection();

  // One-time migration flag (in-memory for session)
  static bool _migrationDone = false;

  String _sessionTypeLabel(String sessionType) {
    return sessionType == 'individual' ? 'Bireysel' : 'Grup';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberTypesState = ref.watch(member_types.memberTypesProvider);
    final memberTypesNotifier = ref.read(
      member_types.memberTypesProvider.notifier,
    );

    // One-time migration for old member type colors
    if (!_migrationDone && memberTypesState.memberTypes.isNotEmpty) {
      // Map of old hex (uppercase) to new hex
      const oldToNew = {
        "#2E5E74": "#F08080",
        "#8CB2AB": "#F0A09F",
        "#F6F6D7": "#DEE0C2",
        "#6F9791": "#B7DF9C",
        "#DDE6DF": "#8CD6BA",
        "#3E5A6E": "#83A8C3",
      };
      // Find member types needing migration
      final toMigrate = memberTypesState.memberTypes.where((mt) {
        final hex = mt.color.toUpperCase();
        return oldToNew.keys.contains(hex);
      }).toList();
      if (toMigrate.isNotEmpty) {
        for (final mt in toMigrate) {
          final newHex = oldToNew[mt.color.toUpperCase()]!;
          final updated = member_types.MemberType(
            id: mt.id,
            name: mt.name,
            color: newHex,
            sessionType: mt.sessionType,
            isCardBased: mt.isCardBased,
            cardUsageFee: mt.cardUsageFee,
          );
          memberTypesNotifier.updateMemberType(updated);
        }
      }
      _migrationDone = true;
    }

    return Stack(
      children: [
        Column(
          children: [
            if (memberTypesState.isLoading) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => memberTypesNotifier.fetchMemberTypes(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: memberTypesState.memberTypes.length,
                  itemBuilder: (context, index) {
                    final type = memberTypesState.memberTypes[index];
                    Color color;
                    try {
                      final hex = type.color.replaceAll('#', '');
                      color = Color(int.parse('FF$hex', radix: 16));
                    } catch (_) {
                      color = kMemberTypeColors[0];
                    }
                    return Card(
                      color: AppDesignTokens.surface,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppDesignTokens.border),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: color),
                        title: Text(type.name, style: AppTypography.cardTitle),
                        subtitle: Text(
                          'Seans Türü: ${_sessionTypeLabel(type.sessionType)}',
                          style: AppTypography.caption,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              style: AppButtonStyles.compactIcon,
                              icon: const Icon(AppIcons.edit),
                              onPressed: () {
                                _showMemberTypeDialog(context, ref, type: type);
                              },
                            ),
                            IconButton(
                              color: AppDesignTokens.destructive,
                              icon: const Icon(AppIcons.delete),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: AppDesignTokens.surface,
                                    title: const Text(
                                      'Sil',
                                      style: AppTypography.sectionTitle,
                                    ),
                                    content: const Text(
                                      'Silmek istediğinize emin misiniz?',
                                      style: AppTypography.body,
                                    ),
                                    actions: [
                                      OutlinedButton.icon(
                                        style: AppButtonStyles.secondary,
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        icon: const Icon(
                                          AppIcons.close,
                                          size: 18,
                                        ),
                                        label: const Text('İptal'),
                                      ),
                                      ElevatedButton.icon(
                                        style: AppButtonStyles.destructive,
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        icon: const Icon(
                                          AppIcons.delete,
                                          size: 18,
                                        ),
                                        label: const Text('Sil'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                final token = await ref
                                    .read(
                                      member_types.memberTypesProvider.notifier,
                                    )
                                    .getToken();
                                if (token == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('No auth token found.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                await ref
                                    .read(
                                      member_types.memberTypesProvider.notifier,
                                    )
                                    .deleteMemberType(token, type.id);
                                final err = ref
                                    .read(member_types.memberTypesProvider)
                                    .error;
                                if (err == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Member type deleted successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $err'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
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
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: AppDesignTokens.primaryAction,
            foregroundColor: AppDesignTokens.primaryActionForeground,
            key: const ValueKey('addMemberTypeFab'),
            onPressed: () => _showMemberTypeDialog(context, ref),
            child: const Icon(AppIcons.create),
            tooltip: 'Üye Tipi Ekle',
          ),
        ),
      ],
    );
  }

  // ...existing code...
}

void _showMemberTypeDialog(
  BuildContext context,
  WidgetRef ref, {
  member_types.MemberType? type,
}) {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: type?.name ?? '');
  String selectedColor = (type != null && type.color.isNotEmpty)
      ? type.color
      : kMemberTypeColorHexes[0];
  final isEdit = type != null;
  String sessionType = type?.sessionType == 'individual'
      ? 'individual'
      : 'group';
  // Always initialize from type for edit, or defaults for create
  bool isCardBased = type?.isCardBased ?? false;
  final cardUsageFeeController = TextEditingController(
    text: (type != null)
        ? (type.cardUsageFee > 0 ? type.cardUsageFee.toString() : '')
        : '',
  );
  // Debug log initial dialog state
  // ignore: avoid_print
  print(
    '[MemberTypeDialog] isEdit=$isEdit isCardBased=$isCardBased cardUsageFee=${type?.cardUsageFee}',
  );

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppDesignTokens.surface,
            title: Text(
              isEdit ? 'Üye Tipini Düzenle' : 'Üye Tipi Ekle',
              style: AppTypography.sectionTitle,
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: _settingsInputDecoration('Ad'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Ad girin' : null,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Renk', style: AppTypography.bodyStrong),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: List.generate(kMemberTypeColors.length, (i) {
                        final hex = kMemberTypeColorHexes[i];
                        final color = kMemberTypeColors[i];
                        return GestureDetector(
                          onTap: () {
                            selectedColor = hex;
                            setState(() {});
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == hex
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              backgroundColor: color,
                              radius: 18,
                              child: selectedColor == hex
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: sessionType,
                      decoration: _settingsInputDecoration('Seans Türü'),
                      items: const [
                        DropdownMenuItem(value: 'group', child: Text('Grup')),
                        DropdownMenuItem(
                          value: 'individual',
                          child: Text('Bireysel'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          sessionType = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Kartlı Üyelik',
                            style: AppTypography.bodyStrong,
                          ),
                        ),
                        Switch(
                          value: isCardBased,
                          activeTrackColor: AppDesignTokens.selectedBackground,
                          activeThumbColor: AppDesignTokens.primaryAction,
                          onChanged: (val) {
                            setState(() {
                              isCardBased = val;
                              if (!isCardBased)
                                cardUsageFeeController.text = '';
                            });
                          },
                        ),
                      ],
                    ),
                    if (isCardBased) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: cardUsageFeeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _settingsInputDecoration(
                          'Kart Basım Tutarı / Card Usage Fee',
                        ),
                        validator: (v) {
                          if (!isCardBased) return null;
                          if (v == null || v.trim().isEmpty)
                            return 'Gerekli / Required';
                          final fee = double.tryParse(v);
                          if (fee == null || fee < 0)
                            return 'Tutar 0 veya daha büyük olmalı / Fee must be >= 0';
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton.icon(
                style: AppButtonStyles.secondary,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(AppIcons.close, size: 18),
                label: const Text('İptal'),
              ),
              ElevatedButton.icon(
                style: AppButtonStyles.primary,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final notifier = ref.read(
                    member_types.memberTypesProvider.notifier,
                  );
                  double fee = 0;
                  if (isCardBased) {
                    fee = double.tryParse(cardUsageFeeController.text) ?? 0;
                  }
                  final newType = member_types.MemberType(
                    id: isEdit ? type.id : '',
                    name: nameController.text.trim(),
                    color: selectedColor,
                    sessionType: sessionType,
                    isCardBased: isCardBased,
                    cardUsageFee: isCardBased ? fee : 0,
                  );
                  if (isEdit) {
                    await notifier.updateMemberType(newType);
                  } else {
                    await notifier.addMemberType(newType);
                  }
                  final err = ref.read(member_types.memberTypesProvider).error;
                  if (err == null) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEdit
                                ? 'Üye tipi güncellendi'
                                : 'Üye tipi eklendi',
                          ),
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Backend error: $err'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(AppIcons.save, size: 18),
                label: Text(isEdit ? 'Kaydet' : 'Ekle'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _PaymentMethodsSection extends ConsumerWidget {
  const _PaymentMethodsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentMethodsState = ref.watch(
      payment_methods.paymentMethodsProvider,
    );
    final paymentMethodsNotifier = ref.read(
      payment_methods.paymentMethodsProvider.notifier,
    );

    return Stack(
      children: [
        Column(
          children: [
            if (paymentMethodsState.isLoading) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    paymentMethodsNotifier.fetchPaymentMethods(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: paymentMethodsState.paymentMethods.length,
                  itemBuilder: (context, index) {
                    final method = paymentMethodsState.paymentMethods[index];
                    return ListTile(
                      title: Text(method.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              _showPaymentMethodDialog(
                                context,
                                ref,
                                method: method,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Payment Method'),
                                  content: const Text(
                                    'Are you sure you want to delete this payment method?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                final token = await ref
                                    .read(
                                      payment_methods
                                          .paymentMethodsProvider
                                          .notifier,
                                    )
                                    .getToken();
                                if (token == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('No auth token found.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                await ref
                                    .read(
                                      payment_methods
                                          .paymentMethodsProvider
                                          .notifier,
                                    )
                                    .deletePaymentMethod(token, method.id);
                                final err = ref
                                    .read(
                                      payment_methods.paymentMethodsProvider,
                                    )
                                    .error;
                                if (err == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Payment method deleted successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          err.isNotEmpty
                                              ? err
                                              : 'Silme işlemi başarısız oldu.',
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            key: const ValueKey('addPaymentMethodFab'),
            onPressed: () => _showPaymentMethodDialog(context, ref),
            child: const Icon(Icons.add),
            tooltip: 'Ödeme Yöntemi Ekle',
          ),
        ),
      ],
    );
  }
}

void _showPaymentMethodDialog(
  BuildContext context,
  WidgetRef ref, {
  payment_methods.PaymentMethod? method,
}) {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: method?.name ?? '');
  final isEdit = method != null;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(isEdit ? 'Ödeme Yöntemini Düzenle' : 'Ödeme Yöntemi Ekle'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Ad'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter name' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final notifier = ref.read(
                payment_methods.paymentMethodsProvider.notifier,
              );
              final newMethod = payment_methods.PaymentMethod(
                id: isEdit ? method.id : '',
                name: nameController.text.trim(),
              );
              if (isEdit) {
                await notifier.updatePaymentMethod(newMethod);
              } else {
                await notifier.addPaymentMethod(newMethod);
              }
              final err = ref
                  .read(payment_methods.paymentMethodsProvider)
                  .error;
              if (err == null) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Payment method updated successfully'
                            : 'Payment method added successfully',
                      ),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Backend error: $err'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Kaydet' : 'Ekle'),
          ),
        ],
      );
    },
  );
}

class _SalonsSection extends ConsumerWidget {
  const _SalonsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonsState = ref.watch(salonsProvider);
    final salonsNotifier = ref.read(salonsProvider.notifier);

    return Stack(
      children: [
        Column(
          children: [
            if (salonsState.isLoading) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => salonsNotifier.fetchSalons(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: salonsState.salons.length,
                  itemBuilder: (context, index) {
                    final salon = salonsState.salons[index];
                    return ListTile(
                      title: Text(salon.name),
                      subtitle: Text(salon.type),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              _showSalonDialog(context, ref, salon: salon);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Salon'),
                                  content: const Text(
                                    'Are you sure you want to delete this salon?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                final token = await ref
                                    .read(salonsProvider.notifier)
                                    .getToken();
                                if (token == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('No auth token found.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                await ref
                                    .read(salonsProvider.notifier)
                                    .deleteSalon(token, salon.id);
                                final err = ref.read(salonsProvider).error;
                                if (err == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Salon deleted successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          err.isNotEmpty
                                              ? err
                                              : 'Silme işlemi başarısız oldu.',
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            key: const ValueKey('addSalonFab'),
            onPressed: () => _showSalonDialog(context, ref),
            child: const Icon(Icons.add),
            tooltip: 'Salon Ekle',
          ),
        ),
      ],
    );
  }
}

void _showSalonDialog(BuildContext context, WidgetRef ref, {Salon? salon}) {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: salon?.name ?? '');
  String type = salon?.type ?? '';
  final isEdit = salon != null;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(isEdit ? 'Salonu Düzenle' : 'Salon Ekle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Ad'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: type.isNotEmpty ? type : null,
                decoration: const InputDecoration(labelText: 'Salon Tipi'),
                items: const [
                  DropdownMenuItem(value: 'Yoga', child: Text('Yoga')),
                  DropdownMenuItem(value: 'Pilates', child: Text('Pilates')),
                ],
                validator: (v) =>
                    v == null || v.isEmpty ? 'Select salon type' : null,
                onChanged: (v) => type = v ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final salonsNotifier = ref.read(salonsProvider.notifier);
              final newSalon = Salon(
                id: isEdit ? salon.id : 0,
                name: nameController.text.trim(),
                type: type,
              );
              if (isEdit) {
                await salonsNotifier.updateSalon(newSalon);
              } else {
                await salonsNotifier.addSalon(newSalon);
              }
              final err = ref.read(salonsProvider).error;
              if (err == null) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Salon updated successfully'
                            : 'Salon added successfully',
                      ),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Backend error: $err'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Kaydet' : 'Ekle'),
          ),
        ],
      );
    },
  );
}

class _EquipmentSection extends ConsumerWidget {
  const _EquipmentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipmentState = ref.watch(equipmentProvider);
    final equipmentNotifier = ref.read(equipmentProvider.notifier);
    final salonsState = ref.watch(salonsProvider);

    return Stack(
      children: [
        Column(
          children: [
            if (equipmentState.isLoading) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => equipmentNotifier.fetchEquipment(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: equipmentState.equipmentList.length,
                  itemBuilder: (context, index) {
                    final equipment = equipmentState.equipmentList[index];
                    final salon = salonsState.salons.firstWhere(
                      (s) => s.id == equipment.salonId,
                      orElse: () => Salon(id: 0, name: 'Unknown', type: ''),
                    );
                    return ListTile(
                      title: Text(equipment.name),
                      subtitle: Text('${equipment.type} • ${salon.name}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              _showEquipmentDialog(
                                context,
                                ref,
                                salonsState.salons,
                                equipment: equipment,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Equipment'),
                                  content: const Text(
                                    'Are you sure you want to delete this equipment?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                final token = await ref
                                    .read(equipmentProvider.notifier)
                                    .getToken();
                                if (token == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('No auth token found.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                await ref
                                    .read(equipmentProvider.notifier)
                                    .deleteEquipment(token, equipment.id);
                                final err = ref.read(equipmentProvider).error;
                                if (err == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Equipment deleted successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          err.isNotEmpty
                                              ? err
                                              : 'Silme işlemi başarısız oldu.',
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            key: const ValueKey('addEquipmentFab'),
            onPressed: () =>
                _showEquipmentDialog(context, ref, salonsState.salons),
            child: const Icon(Icons.add),
            tooltip: 'Ekipman Ekle',
          ),
        ),
      ],
    );
  }
}

void _showEquipmentDialog(
  BuildContext context,
  WidgetRef ref,
  List<Salon> salons, {
  Equipment? equipment,
}) {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: equipment?.name ?? '');
  String type = equipment?.type ?? '';
  int? selectedSalonId = equipment?.salonId;
  final isEdit = equipment != null;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(isEdit ? 'Ekipmanı Düzenle' : 'Ekipman Ekle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Ad'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: type.isNotEmpty ? type : null,
                decoration: const InputDecoration(labelText: 'Ekipman Tipi'),
                items: const [
                  DropdownMenuItem(value: 'Mat', child: Text('Mat')),
                  DropdownMenuItem(value: 'Reformer', child: Text('Reformer')),
                ],
                validator: (v) =>
                    v == null || v.isEmpty ? 'Select equipment type' : null,
                onChanged: (v) => type = v ?? '',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedSalonId,
                decoration: const InputDecoration(labelText: 'Salon'),
                items: salons
                    .map(
                      (salon) => DropdownMenuItem(
                        value: salon.id,
                        child: Text('${salon.name} (${salon.type})'),
                      ),
                    )
                    .toList(),
                validator: (v) => v == null ? 'Select salon' : null,
                onChanged: (v) => selectedSalonId = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              // Business rules: Yoga salons must use Mat, Pilates salons must use Reformer
              final selectedSalon = salons.firstWhere(
                (s) => s.id == selectedSalonId,
                orElse: () => Salon(id: 0, name: '', type: ''),
              );
              if ((selectedSalon.type == 'Yoga' && type != 'Mat') ||
                  (selectedSalon.type == 'Pilates' && type != 'Reformer')) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Invalid combination: $type can only be assigned to ${selectedSalon.type} salons.',
                      ),
                    ),
                  );
                }
                return;
              }
              final equipmentNotifier = ref.read(equipmentProvider.notifier);
              final newEquipment = Equipment(
                id: isEdit ? equipment.id : 0,
                name: nameController.text.trim(),
                type: type,
                salonId: selectedSalonId!,
              );
              if (isEdit) {
                await equipmentNotifier.updateEquipment(newEquipment, []);
              } else {
                await equipmentNotifier.addEquipment(newEquipment);
              }
              final err = ref.read(equipmentProvider).error;
              if (err == null) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Equipment updated successfully'
                            : 'Equipment added successfully',
                      ),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Backend error: $err'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Kaydet' : 'Ekle'),
          ),
        ],
      );
    },
  );
}
