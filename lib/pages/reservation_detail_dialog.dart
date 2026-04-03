import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../models/member.dart';
import '../models/salon.dart';

class ReservationDetailDialog extends StatelessWidget {
  final Reservation reservation;
  final Member? member;
  final Salon? salon;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReservationDetailDialog({
    Key? key,
    required this.reservation,
    required this.member,
    required this.salon,
    required this.canEdit,
    required this.canDelete,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color? memberTypeColor;
    try {
      final hex = reservation.memberTypeColor.replaceAll('#', '');
      memberTypeColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      memberTypeColor = const Color(0xFF116478);
    }
    // textColor computed but not used; removed to resolve warning.
    return AlertDialog(
      title: Text('Reservation Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (member != null) ...[
            Text(
              'Member: ${member!.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: memberTypeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  member?.memberTypeName ?? '',
                  style: TextStyle(
                    color: memberTypeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          if (salon != null) Text('Salon: \\${salon!.name}'),
          Text(
            'Date: \\${reservation.date.year}-\\${reservation.date.month.toString().padLeft(2, '0')}-\\${reservation.date.day.toString().padLeft(2, '0')}',
          ),
          Text('Time: \\${reservation.hour.toString().padLeft(2, '0')}:00'),
        ],
      ),
      actions: [
        if (canEdit) TextButton(onPressed: onEdit, child: const Text('Edit')),
        if (canDelete)
          TextButton(
            onPressed: onDelete,
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
