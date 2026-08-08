import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../l10n/app_localizations.dart';

class ReservationDetailDialog extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onEdit;

  const ReservationDetailDialog({
    Key? key,
    required this.reservation,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    Color? memberTypeColor;
    try {
      final hex = reservation.memberTypeColor.replaceAll('#', '');
      memberTypeColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      memberTypeColor = const Color(0xFF8CB2AB);
    }
    return AlertDialog(
      title: Text(
        loc?.translate('reservationDetails') ?? 'Reservation Details',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${loc?.translate('member') ?? 'Member'}: ${reservation.memberName}',
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
                reservation.memberTypeName,
                style: TextStyle(
                  color: memberTypeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text('${loc?.translate('salon') ?? 'Salon'}: ${reservation.salonId}'),
          Text(
            '${loc?.translate('equipment') ?? 'Equipment'}: ${reservation.equipmentId}',
          ),
          Text(
            '${loc?.translate('date') ?? 'Date'}: ${reservation.date.year}-${reservation.date.month.toString().padLeft(2, '0')}-${reservation.date.day.toString().padLeft(2, '0')}',
          ),
          Text(
            '${loc?.translate('time') ?? 'Time'}: ${reservation.hour.toString().padLeft(2, '0')}:${reservation.minute.toString().padLeft(2, '0')}',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onEdit,
          child: Text(loc?.translate('edit') ?? 'Edit'),
        ),
        TextButton(
          onPressed: () async {
            if (reservation.recurrenceGroupId != null &&
                reservation.recurrenceGroupId!.isNotEmpty) {
              await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Rezervasyonu Sil'),
                  content: const Text(
                    'Bu tekrarlı bir rezervasyon. Ne yapmak istiyorsunuz?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop('single');
                      },
                      child: const Text('Sadece Bu Rezervasyon'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop('future');
                      },
                      child: const Text('Bu ve Gelecek Rezervasyonlar'),
                    ),
                  ],
                ),
              );
            } else {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(
                    loc?.translate('deleteReservation') ?? 'Delete Reservation',
                  ),
                  content: Text(
                    loc?.translate('deleteReservationConfirm') ??
                        'Are you sure you want to delete this reservation?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(loc?.translate('cancel') ?? 'Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        loc?.translate('delete') ?? 'Delete',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                Navigator.of(context).pop('single');
              }
            }
          },
          child: Text(
            loc?.translate('delete') ?? 'Delete',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc?.translate('close') ?? 'Close'),
        ),
      ],
    );
  }
}
