import 'reservations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reservation.dart';
import '../models/member.dart';
import '../providers/reservation_provider.dart';
import '../providers/salons_provider.dart';

class ReservationFormDialog extends ConsumerStatefulWidget {
  final DateTime date;
  final int hour;
  final int salonId;
  final int equipmentId;
  final List<Member> members;
  final String token;
  final String role;
  final List<int> assignedSalonIds;
  final Reservation? initialReservation;

  const ReservationFormDialog({
    Key? key,
    required this.date,
    required this.hour,
    required this.salonId,
    required this.equipmentId,
    required this.members,
    required this.token,
    required this.role,
    required this.assignedSalonIds,
    this.initialReservation,
  }) : super(key: key);

  @override
  ConsumerState<ReservationFormDialog> createState() =>
      _ReservationFormDialogState();
}

class _ReservationFormDialogState extends ConsumerState<ReservationFormDialog> {
  late int? _selectedMemberId;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.initialReservation?.memberId;
  }

  bool get _canSubmit {
    if (_selectedMemberId == null) return false;
    if (widget.date.isBefore(DateTime.now().subtract(const Duration(days: 1))))
      return false;
    if (widget.salonId == 0 || widget.equipmentId == 0) return false;
    if (widget.role == 'instructor' &&
        !widget.assignedSalonIds.contains(widget.salonId))
      return false;
    return true;
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final member = widget.members.firstWhere((m) => m.id == _selectedMemberId);
    final reservation = Reservation(
      id: 0,
      date: widget.date,
      hour: widget.hour,
      salonId: widget.salonId,
      equipmentId: widget.equipmentId,
      memberId: member.id,
      memberName: member.name,
      memberTypeColor: member.memberTypeColor,
    );
    final result = await ref
        .read(reservationsProvider.notifier)
        .addReservation(reservation, widget.token);
    setState(() => _isSubmitting = false);
    if (result == null) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Reservation created successfully!',
              style: TextStyle(color: kBrandTextColor),
            ),
            backgroundColor: kBrandAccentColor,
          ),
        );
      }
    } else {
      setState(() => _errorText = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Filtering logic ---
    // Get salon type (Yoga/Pilates) for filtering

    final salons = ref.read(salonsProvider).salons;
    final salon = salons.where((s) => s.id == widget.salonId).isNotEmpty
        ? salons.firstWhere((s) => s.id == widget.salonId)
        : null;
    final salonType = salon != null ? salon.type.toLowerCase() : '';

    // Filter members by salon type
    List<Member> filteredMembers = widget.members.where((m) {
      if (!m.assignedSalonIds.contains(widget.salonId)) return false;
      if (salonType == 'yoga' && m.memberTypeName.toLowerCase() == 'yoga')
        return true;
      if (salonType == 'pilates' && m.memberTypeName.toLowerCase() == 'pilates')
        return true;
      // If member belongs to both, show in both
      if (m.memberTypeName.toLowerCase().contains(salonType)) return true;
      return false;
    }).toList();

    // If member belongs to both, show in both (by type name containing both)
    // Already handled above

    // Filter equipment by salon and type
    // If you want to use filteredEquipment for a dropdown, add it to the UI.

    return AlertDialog(
      backgroundColor: kBrandBackgroundColor,
      title: Text(
        widget.initialReservation == null
            ? 'Add Reservation'
            : 'Edit Reservation',
        style: const TextStyle(color: kBrandTextColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            value: _selectedMemberId,
            hint: const Text(
              'Select Member',
              style: TextStyle(color: kBrandTextColor),
            ),
            items: filteredMembers
                .map(
                  (m) => DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      m.name,
                      style: const TextStyle(color: kBrandTextColor),
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) => setState(() => _selectedMemberId = id),
            decoration: InputDecoration(
              filled: true,
              fillColor: kBrandBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _errorText!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: kBrandTextColor)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandAccentColor,
            foregroundColor: kBrandTextColor,
          ),
          onPressed: !_canSubmit || _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kBrandTextColor,
                  ),
                )
              : const Text('Save', style: TextStyle(color: kBrandTextColor)),
        ),
      ],
    );
  }
}
