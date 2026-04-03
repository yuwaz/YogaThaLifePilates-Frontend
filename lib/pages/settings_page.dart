import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/salons_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/member_types_provider.dart';
import '../providers/instructors_provider.dart';
import '../providers/lesson_packages_provider.dart';
import '../providers/payment_methods_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/salon.dart';
import '../models/equipment.dart';
import '../providers/member_types_provider.dart' show MemberType;
import '../providers/instructors_provider.dart' show Instructor;
import '../providers/lesson_packages_provider.dart' show LessonPackage;
import '../providers/payment_methods_provider.dart' show PaymentMethod;

const Color kBrandTextColor = Color(0xFF116478);
const Color kBrandBackgroundColor = Color(0xFFF6F6D7);
const Color kBrandAccentColor = Color(0xFF8CB2AB);

class SettingsPage extends ConsumerWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: kBrandBackgroundColor,
        appBar: AppBar(
          backgroundColor: kBrandAccentColor,
          title: Text(
            AppLocalizations.of(context)?.translate('settings') ?? 'Settings',
            style: const TextStyle(color: kBrandTextColor),
          ),
          iconTheme: const IconThemeData(color: kBrandTextColor),
          bottom: TabBar(
            isScrollable: true,
            labelColor: kBrandTextColor,
            indicatorColor: kBrandAccentColor,
            tabs: [
              Tab(
                text:
                    AppLocalizations.of(context)?.translate('salon') ??
                    'Salons',
              ),
              Tab(
                text:
                    AppLocalizations.of(context)?.translate('equipment') ??
                    'Equipment',
              ),
              Tab(
                text:
                    AppLocalizations.of(context)?.translate('memberType') ??
                    'Member Types',
              ),
              Tab(text: 'Instructors'),
              Tab(
                text:
                    AppLocalizations.of(context)?.translate('lessonPackages') ??
                    'Lesson Packages',
              ),
              Tab(
                text:
                    AppLocalizations.of(context)?.translate('payments') ??
                    'Payment Methods',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SalonsSection(),
            _EquipmentSection(),
            _MemberTypesSection(),
            _InstructorsSection(),
            _LessonPackagesSection(),
            _PaymentMethodsSection(),
          ],
        ),
      ),
    );
  }
}

// --- Salons Section ---
class _SalonsSection extends ConsumerWidget {
  const _SalonsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(salonsProvider);
    return Stack(
      children: [
        state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: state.salons.length,
                itemBuilder: (context, i) {
                  final salon = state.salons[i];
                  return ListTile(
                    title: Text(
                      salon.name,
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () =>
                              _showSalonDialog(context, ref, salon: salon),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () => _deleteSalon(context, ref, salon.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: kBrandAccentColor,
            onPressed: () => _showSalonDialog(context, ref),
            child: const Icon(Icons.add, color: kBrandTextColor),
          ),
        ),
      ],
    );
  }
}

void _showSalonDialog(BuildContext context, WidgetRef ref, {salon}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final _formKey = GlobalKey<FormState>();
      String name = salon?.name ?? '';
      String type = salon?.type ?? 'Yoga';
      bool isLoading = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              salon == null
                  ? (AppLocalizations.of(context)?.translate('add') ?? 'Add') +
                        ' ' +
                        (AppLocalizations.of(context)?.translate('salon') ??
                            'Salon')
                  : (AppLocalizations.of(context)?.translate('edit') ??
                            'Edit') +
                        ' ' +
                        (AppLocalizations.of(context)?.translate('salon') ??
                            'Salon'),
            ),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context)?.translate('name') ??
                          'Name',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? (AppLocalizations.of(context)?.translate('name') ??
                              'Enter name')
                        : null,
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(
                            context,
                          )?.translate('memberType') ??
                          'Type',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Yoga', child: Text('Yoga')),
                      DropdownMenuItem(
                        value: 'Pilates',
                        child: Text('Pilates'),
                      ),
                    ],
                    onChanged: (v) => setState(() => type = v ?? 'Yoga'),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel',
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandAccentColor,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          final salonObj = Salon(
                            id: salon?.id ?? 0,
                            name: name.trim(),
                            type: type,
                          );
                          if (salon == null) {
                            await ref
                                .read(salonsProvider.notifier)
                                .addSalon(salonObj);
                          } else {
                            await ref
                                .read(salonsProvider.notifier)
                                .updateSalon(salonObj);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  salon == null
                                      ? 'Salon added'
                                      : 'Salon updated',
                                ),
                                backgroundColor: kBrandAccentColor,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: \\${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted)
                            setState(() => isLoading = false);
                        }
                      },
                child: Text(
                  salon == null
                      ? (AppLocalizations.of(context)?.translate('add') ??
                            'Add')
                      : (AppLocalizations.of(context)?.translate('save') ??
                            'Save'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void _deleteSalon(BuildContext context, WidgetRef ref, int id) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        AppLocalizations.of(context)?.translate('delete') ?? 'Delete',
      ),
      content: Text(
        AppLocalizations.of(context)?.translate('delete') ??
            'Are you sure you want to delete this item?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel',
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            AppLocalizations.of(context)?.translate('delete') ?? 'Delete',
          ),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(salonsProvider.notifier).deleteSalon(id);
  }
}

// --- Equipment Section ---
class _EquipmentSection extends ConsumerWidget {
  const _EquipmentSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(equipmentProvider);
    return Stack(
      children: [
        state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: state.equipmentList.length,
                itemBuilder: (context, i) {
                  final equipment = state.equipmentList[i];
                  return ListTile(
                    title: Text(
                      equipment.name,
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () => _showEquipmentDialog(
                            context,
                            ref,
                            equipment: equipment,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () =>
                              _deleteEquipment(context, ref, equipment.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: kBrandAccentColor,
            onPressed: () => _showEquipmentDialog(context, ref),
            child: const Icon(Icons.add, color: kBrandTextColor),
          ),
        ),
      ],
    );
  }
}

void _showEquipmentDialog(BuildContext context, WidgetRef ref, {equipment}) {
  final salonsState = ref.read(salonsProvider);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final _formKey = GlobalKey<FormState>();
      String name = equipment?.name ?? '';
      String type = equipment?.type ?? 'Mat';
      int? salonId =
          equipment?.salonId ??
          (salonsState.salons.isNotEmpty ? salonsState.salons.first.id : null);
      bool isLoading = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(equipment == null ? 'Add Equipment' : 'Edit Equipment'),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter name' : null,
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'Mat', child: Text('Mat')),
                      DropdownMenuItem(
                        value: 'Reformer',
                        child: Text('Reformer'),
                      ),
                    ],
                    onChanged: (v) => setState(() => type = v ?? 'Mat'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: salonId,
                    decoration: const InputDecoration(labelText: 'Salon'),
                    items: salonsState.salons
                        .map<DropdownMenuItem<int>>(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => salonId = v),
                    validator: (v) => v == null ? 'Select salon' : null,
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandAccentColor,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          final equipmentObj = Equipment(
                            id: equipment?.id ?? 0,
                            name: name.trim(),
                            type: type,
                            salonId: salonId!,
                          );
                          if (equipment == null) {
                            await ref
                                .read(equipmentProvider.notifier)
                                .addEquipment(equipmentObj, []);
                          } else {
                            await ref
                                .read(equipmentProvider.notifier)
                                .updateEquipment(equipmentObj, []);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  equipment == null
                                      ? 'Equipment added'
                                      : 'Equipment updated',
                                ),
                                backgroundColor: kBrandAccentColor,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: \\${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted)
                            setState(() => isLoading = false);
                        }
                      },
                child: Text(
                  equipment == null ? 'Add' : 'Save',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void _deleteEquipment(BuildContext context, WidgetRef ref, int id) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Equipment'),
      content: const Text('Are you sure you want to delete this equipment?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(equipmentProvider.notifier).deleteEquipment(id);
  }
}

// --- Member Types Section ---
class _MemberTypesSection extends ConsumerWidget {
  const _MemberTypesSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memberTypesProvider);
    return Stack(
      children: [
        state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: state.memberTypes.length,
                itemBuilder: (context, i) {
                  final type = state.memberTypes[i];
                  return ListTile(
                    title: Text(
                      type.name,
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    subtitle: Text(
                      'Color: ${type.color}',
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () => _showMemberTypeDialog(
                            context,
                            ref,
                            memberType: type,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () =>
                              _deleteMemberType(context, ref, type.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: kBrandAccentColor,
            onPressed: () => _showMemberTypeDialog(context, ref),
            child: const Icon(Icons.add, color: kBrandTextColor),
          ),
        ),
      ],
    );
  }
}

void _showMemberTypeDialog(BuildContext context, WidgetRef ref, {memberType}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final _formKey = GlobalKey<FormState>();
      String name = memberType?.name ?? '';
      // Default to first color if not set
      String color = memberType?.color ?? '#116478';
      bool isLoading = false;

      // 6 brand-compatible, visually distinct colors
      const colorOptions = [
        '#116478',
        '#8cb2ab',
        '#f6f6d7',
        '#5f8f88',
        '#d7e8df',
        '#2f4f5f',
      ];

      Color _parseColor(String hex) {
        hex = hex.replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        return Color(int.parse(hex, radix: 16));
      }

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              memberType == null ? 'Add Member Type' : 'Edit Member Type',
            ),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter name' : null,
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Color',
                      style: TextStyle(color: kBrandTextColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in colorOptions)
                        ChoiceChip(
                          label: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _parseColor(c),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color == c
                                    ? kBrandTextColor
                                    : Colors.grey.shade300,
                                width: color == c ? 2 : 1,
                              ),
                            ),
                          ),
                          selected: color == c,
                          onSelected: (_) => setState(() => color = c),
                          selectedColor: _parseColor(c),
                          backgroundColor: Colors.transparent,
                        ),
                    ],
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandAccentColor,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          final memberTypeObj = MemberType(
                            id: memberType?.id ?? '',
                            name: name.trim(),
                            color: color.trim(),
                          );
                          if (memberType == null) {
                            await ref
                                .read(memberTypesProvider.notifier)
                                .addMemberType(memberTypeObj);
                          } else {
                            await ref
                                .read(memberTypesProvider.notifier)
                                .updateMemberType(memberTypeObj);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  memberType == null
                                      ? 'Member type added'
                                      : 'Member type updated',
                                ),
                                backgroundColor: kBrandAccentColor,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: \\${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted)
                            setState(() => isLoading = false);
                        }
                      },
                child: Text(
                  memberType == null ? 'Add' : 'Save',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void _deleteMemberType(BuildContext context, WidgetRef ref, String id) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Member Type'),
      content: const Text('Are you sure you want to delete this member type?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(memberTypesProvider.notifier).deleteMemberType(id);
  }
}

// --- Instructors Section ---
class _InstructorsSection extends ConsumerWidget {
  const _InstructorsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(instructorsProvider);
    return Stack(
      children: [
        state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: state.instructors.length,
                itemBuilder: (context, i) {
                  final instructor = state.instructors[i];
                  return ListTile(
                    title: Text(
                      instructor.name,
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    subtitle: Text(
                      'Roles: ${instructor.permissionRoles.join(", ")}',
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () => _showInstructorDialog(
                            context,
                            ref,
                            instructor: instructor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () =>
                              _deleteInstructor(context, ref, instructor.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: kBrandAccentColor,
            onPressed: () => _showInstructorDialog(context, ref),
            child: const Icon(Icons.add, color: kBrandTextColor),
          ),
        ),
      ],
    );
  }
}

void _showInstructorDialog(BuildContext context, WidgetRef ref, {instructor}) {
  final salonsState = ref.read(salonsProvider);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final _formKey = GlobalKey<FormState>();
      String username = instructor?.name ?? '';
      List<String> assignedSalonIds = List<String>.from(
        instructor?.assignedSalonIds ?? [],
      );
      List<String> permissions = List<String>.from(
        instructor?.permissionRoles ?? [],
      );
      bool isLoading = false;

      final allSalonIds = salonsState.salons
          .map((s) => s.id.toString())
          .toList();
      final allPermissions = ['admin', 'instructor'];

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              instructor == null ? 'Add Instructor' : 'Edit Instructor',
            ),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: username,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter username'
                          : null,
                      onChanged: (v) => username = v,
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Assigned Salons',
                      ),
                      child: Column(
                        children: allSalonIds.map((id) {
                          final salon = salonsState.salons.firstWhere(
                            (s) => s.id.toString() == id,
                          );
                          return CheckboxListTile(
                            title: Text(salon.name),
                            value: assignedSalonIds.contains(id),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  assignedSalonIds.add(id);
                                } else {
                                  assignedSalonIds.remove(id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Permissions',
                      ),
                      child: Column(
                        children: allPermissions
                            .map(
                              (perm) => CheckboxListTile(
                                title: Text(perm),
                                value: permissions.contains(perm),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      permissions.add(perm);
                                    } else {
                                      permissions.remove(perm);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandAccentColor,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          final instructorObj = Instructor(
                            id: instructor?.id ?? '',
                            name: username.trim(),
                            assignedSalonIds: assignedSalonIds,
                            permissionRoles: permissions,
                          );
                          if (instructor == null) {
                            await ref
                                .read(instructorsProvider.notifier)
                                .addInstructor(instructorObj);
                          } else {
                            await ref
                                .read(instructorsProvider.notifier)
                                .updateInstructor(instructorObj);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  instructor == null
                                      ? 'Instructor added'
                                      : 'Instructor updated',
                                ),
                                backgroundColor: kBrandAccentColor,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: \\${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted)
                            setState(() => isLoading = false);
                        }
                      },
                child: Text(
                  instructor == null ? 'Add' : 'Save',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void _deleteInstructor(BuildContext context, WidgetRef ref, String id) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Instructor'),
      content: const Text('Are you sure you want to delete this instructor?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(instructorsProvider.notifier).deleteInstructor(id);
  }
}

// --- Lesson Packages Section ---
class _LessonPackagesSection extends ConsumerWidget {
  const _LessonPackagesSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lessonPackagesProvider);
    return Stack(
      children: [
        state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: state.lessonPackages.length,
                itemBuilder: (context, i) {
                  final pkg = state.lessonPackages[i];
                  return ListTile(
                    title: Text(
                      pkg.name,
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    subtitle: Text(
                      'Lessons: ${pkg.lessonCount}, Price: ${pkg.price}',
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () => _showLessonPackageDialog(
                            context,
                            ref,
                            lessonPackage: pkg,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () =>
                              _deleteLessonPackage(context, ref, pkg.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: kBrandAccentColor,
            onPressed: () => _showLessonPackageDialog(context, ref),
            child: const Icon(Icons.add, color: kBrandTextColor),
          ),
        ),
      ],
    );
  }
}

void _showLessonPackageDialog(
  BuildContext context,
  WidgetRef ref, {
  lessonPackage,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final _formKey = GlobalKey<FormState>();
      String name = lessonPackage?.name ?? '';
      String lessonCount = lessonPackage?.lessonCount?.toString() ?? '';
      String price = lessonPackage?.price?.toString() ?? '';
      bool isLoading = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              lessonPackage == null
                  ? 'Add Lesson Package'
                  : 'Edit Lesson Package',
            ),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter name' : null,
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: lessonCount,
                    decoration: const InputDecoration(
                      labelText: 'Lesson Count',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || int.tryParse(v) == null
                        ? 'Enter valid lesson count'
                        : null,
                    onChanged: (v) => lessonCount = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: price,
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => v == null || double.tryParse(v) == null
                        ? 'Enter valid price'
                        : null,
                    onChanged: (v) => price = v,
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandAccentColor,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          final lessonPackageObj = LessonPackage(
                            id: lessonPackage?.id ?? '',
                            name: name.trim(),
                            lessonCount: int.parse(lessonCount),
                            price: double.parse(price),
                          );
                          if (lessonPackage == null) {
                            await ref
                                .read(lessonPackagesProvider.notifier)
                                .addLessonPackage(lessonPackageObj);
                          } else {
                            await ref
                                .read(lessonPackagesProvider.notifier)
                                .updateLessonPackage(lessonPackageObj);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  lessonPackage == null
                                      ? 'Lesson package added'
                                      : 'Lesson package updated',
                                ),
                                backgroundColor: kBrandAccentColor,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: \\${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted)
                            setState(() => isLoading = false);
                        }
                      },
                child: Text(
                  lessonPackage == null ? 'Add' : 'Save',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void _deleteLessonPackage(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Lesson Package'),
      content: const Text(
        'Are you sure you want to delete this lesson package?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(lessonPackagesProvider.notifier).deleteLessonPackage(id);
  }
}

// --- Payment Methods Section ---
class _PaymentMethodsSection extends ConsumerWidget {
  const _PaymentMethodsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentMethodsProvider);
    return Stack(
      children: [
        state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: state.paymentMethods.length,
                itemBuilder: (context, i) {
                  final method = state.paymentMethods[i];
                  return ListTile(
                    title: Text(
                      method.name,
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () => _showPaymentMethodDialog(
                            context,
                            ref,
                            paymentMethod: method,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: kBrandAccentColor,
                          ),
                          onPressed: () =>
                              _deletePaymentMethod(context, ref, method.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: kBrandAccentColor,
            onPressed: () => _showPaymentMethodDialog(context, ref),
            child: const Icon(Icons.add, color: kBrandTextColor),
          ),
        ),
      ],
    );
  }
}

void _showPaymentMethodDialog(
  BuildContext context,
  WidgetRef ref, {
  paymentMethod,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final _formKey = GlobalKey<FormState>();
      String name = paymentMethod?.name ?? '';
      bool isLoading = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              paymentMethod == null
                  ? 'Add Payment Method'
                  : 'Edit Payment Method',
            ),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter name' : null,
                    onChanged: (v) => name = v,
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandAccentColor,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          final paymentMethodObj = PaymentMethod(
                            id: paymentMethod?.id ?? '',
                            name: name.trim(),
                          );
                          if (paymentMethod == null) {
                            await ref
                                .read(paymentMethodsProvider.notifier)
                                .addPaymentMethod(paymentMethodObj);
                          } else {
                            await ref
                                .read(paymentMethodsProvider.notifier)
                                .updatePaymentMethod(paymentMethodObj);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  paymentMethod == null
                                      ? 'Payment method added'
                                      : 'Payment method updated',
                                ),
                                backgroundColor: kBrandAccentColor,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: \\${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted)
                            setState(() => isLoading = false);
                        }
                      },
                child: Text(
                  paymentMethod == null ? 'Add' : 'Save',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void _deletePaymentMethod(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Payment Method'),
      content: const Text(
        'Are you sure you want to delete this payment method?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(paymentMethodsProvider.notifier).deletePaymentMethod(id);
  }
}
