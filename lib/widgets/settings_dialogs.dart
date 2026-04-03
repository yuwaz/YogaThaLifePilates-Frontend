import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Color kBrandTextColor = Color(0xFF116478);
const Color kBrandBackgroundColor = Color(0xFFF6F6D7);
const Color kBrandAccentColor = Color(0xFF8CB2AB);

// Example: Salon Add/Edit Dialog
Future<void> showSalonDialog(
  BuildContext context,
  WidgetRef ref, {
  salon,
  required Function onSaved,
}) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: salon?.name ?? '');
  bool isLoading = false;
  String? error;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: kBrandBackgroundColor,
            title: Text(
              salon == null ? 'Add Salon' : 'Edit Salon',
              style: const TextStyle(color: kBrandTextColor),
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Salon Name'),
                style: const TextStyle(color: kBrandTextColor),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
            actions: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: kBrandTextColor),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandAccentColor,
                  foregroundColor: kBrandTextColor,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          await onSaved(nameController.text);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Salon saved successfully!'),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() {
                            error = e.toString();
                            isLoading = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

// Example: Instructor Add/Edit Dialog with Multi-Select
Future<void> showInstructorDialog(
  BuildContext context,
  WidgetRef ref, {
  instructor,
  required List<String> allSalonIds,
  required List<String> allRoles,
  required Function(
    String name,
    List<String> selectedSalons,
    List<String> selectedRoles,
  )
  onSaved,
}) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: instructor?.name ?? '');
  List<String> selectedSalons = List<String>.from(
    instructor?.assignedSalonIds ?? [],
  );
  List<String> selectedRoles = List<String>.from(
    instructor?.permissionRoles ?? [],
  );
  bool isLoading = false;
  String? error;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: kBrandBackgroundColor,
            title: Text(
              instructor == null ? 'Add Instructor' : 'Edit Instructor',
              style: const TextStyle(color: kBrandTextColor),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Instructor Name',
                      ),
                      style: const TextStyle(color: kBrandTextColor),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    // Multi-select for Salons
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Assigned Salons',
                      ),
                      child: Wrap(
                        spacing: 8,
                        children: allSalonIds.map((id) {
                          final selected = selectedSalons.contains(id);
                          return FilterChip(
                            label: Text(
                              id,
                              style: const TextStyle(color: kBrandTextColor),
                            ),
                            selected: selected,
                            selectedColor: kBrandAccentColor,
                            checkmarkColor: kBrandTextColor,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  selectedSalons.add(id);
                                } else {
                                  selectedSalons.remove(id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Multi-select for Roles
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Permission Roles',
                      ),
                      child: Wrap(
                        spacing: 8,
                        children: allRoles.map((role) {
                          final selected = selectedRoles.contains(role);
                          return FilterChip(
                            label: Text(
                              role,
                              style: const TextStyle(color: kBrandTextColor),
                            ),
                            selected: selected,
                            selectedColor: kBrandAccentColor,
                            checkmarkColor: kBrandTextColor,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  selectedRoles.add(role);
                                } else {
                                  selectedRoles.remove(role);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: kBrandTextColor),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandAccentColor,
                  foregroundColor: kBrandTextColor,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          await onSaved(
                            nameController.text,
                            selectedSalons,
                            selectedRoles,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Instructor saved successfully!'),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() {
                            error = e.toString();
                            isLoading = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

// Repeat similar dialog patterns for Equipment, MemberType, LessonPackage, PaymentMethod as needed.
// Each dialog should use form validation, call the appropriate provider for save, and show snackbar on success/error.
