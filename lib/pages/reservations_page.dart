import 'package:intl/intl.dart';
import '../providers/member_types_provider.dart';
import '../models/member.dart';
import '../models/reservation.dart';
import 'reservation_form_dialog.dart';
import 'reservation_detail_dialog.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
// import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/salons_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/member_provider.dart';
import '../providers/reservation_provider.dart';
import '../l10n/app_localizations.dart';

const Color kBrandAccentColor = Color(0xFF116478);
const Color kBrandBackgroundColor = Color(0xFFF6F6D7);
const Color kBrandTextColor = Color(0xFF1C1C1E);

const int reservationDurationMinutes = 50;
const double hourRowHeight = 64;

class ReservationsPage extends ConsumerStatefulWidget {
  final String token;
  final String role;
  final List<int> assignedSalonIds;

  const ReservationsPage({
    super.key,
    required this.token,
    required this.role,
    required this.assignedSalonIds,
  });

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

// New grid: generates slots based on equipment count for the selected salon
class _EquipmentReservationGrid extends StatefulWidget {
  final List<DateTime> dates;
  final List<int> hours;
  final int salonId;
  final List equipmentList;
  final String token;
  final String role;
  final List reservations;
  final List members;
  final List memberTypes;
  final bool isAdmin;
  final int? selectedInstructorId;
  final bool compactLayout;
  final Future<void> Function()? onRefresh;

  const _EquipmentReservationGrid({
    Key? key,
    required this.dates,
    required this.hours,
    required this.salonId,
    required this.equipmentList,
    required this.token,
    required this.role,
    required this.reservations,
    required this.members,
    required this.memberTypes,
    required this.isAdmin,
    this.selectedInstructorId,
    this.compactLayout = false,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<_EquipmentReservationGrid> createState() =>
      _EquipmentReservationGridState();
}

class _ReservationDragData {
  final Reservation reservation;

  const _ReservationDragData({required this.reservation});
}

class _EquipmentReservationGridState extends State<_EquipmentReservationGrid> {
  static const double slotWidth = 36;
  static const double slotHorizontalMargin = 1;
  static const double slotPitch = slotWidth + (slotHorizontalMargin * 2);

  late final ScrollController _headerHorizontalController;
  late final ScrollController _bodyHorizontalController;
  bool _syncingFromHeader = false;
  bool _syncingFromBody = false;
  ({DateTime date, int hour, int minute, int equipmentId})? _activeDragTarget;

  bool _sameActiveTarget(
    ({DateTime date, int hour, int minute, int equipmentId})? first,
    ({DateTime date, int hour, int minute, int equipmentId})? second,
  ) {
    if (first == null || second == null) {
      return first == second;
    }

    return _dateKey(first.date) == _dateKey(second.date) &&
        first.hour == second.hour &&
        first.minute == second.minute &&
        first.equipmentId == second.equipmentId;
  }

  void _setActiveDragTarget(
    ({DateTime date, int hour, int minute, int equipmentId})? target,
  ) {
    if (_sameActiveTarget(_activeDragTarget, target) || !mounted) {
      return;
    }

    setState(() {
      _activeDragTarget = target;
    });
  }

  void _clearActiveDragTarget() {
    if (_activeDragTarget == null || !mounted) {
      return;
    }

    setState(() {
      _activeDragTarget = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _headerHorizontalController = ScrollController();
    _bodyHorizontalController = ScrollController();
    _headerHorizontalController.addListener(_syncHeaderToBody);
    _bodyHorizontalController.addListener(_syncBodyToHeader);
  }

  @override
  void dispose() {
    _headerHorizontalController.removeListener(_syncHeaderToBody);
    _bodyHorizontalController.removeListener(_syncBodyToHeader);
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    super.dispose();
  }

  double _clampOffset(ScrollController controller, double target) {
    if (!controller.hasClients) return 0;
    final position = controller.position;
    return target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  void _syncHeaderToBody() {
    if (_syncingFromBody) return;
    _syncingFromHeader = true;
    if (_bodyHorizontalController.hasClients) {
      final target = _clampOffset(
        _bodyHorizontalController,
        _headerHorizontalController.offset,
      );
      if ((_bodyHorizontalController.offset - target).abs() > 0.5) {
        _bodyHorizontalController.jumpTo(target);
      }
    }
    _syncingFromHeader = false;
  }

  void _syncBodyToHeader() {
    if (_syncingFromHeader) return;
    _syncingFromBody = true;
    if (_headerHorizontalController.hasClients) {
      final target = _clampOffset(
        _headerHorizontalController,
        _bodyHorizontalController.offset,
      );
      if ((_headerHorizontalController.offset - target).abs() > 0.5) {
        _headerHorizontalController.jumpTo(target);
      }
    }
    _syncingFromBody = false;
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _slotStartKey({
    required int salonId,
    required DateTime date,
    required int hour,
    required int equipmentId,
  }) {
    return '$salonId|${_dateKey(date)}|$hour|$equipmentId';
  }

  String _formatDragDate(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  String _formatDragTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String _equipmentNameFor(int equipmentId) {
    for (final equipment in widget.equipmentList) {
      if (equipment.id == equipmentId) {
        return equipment.name.toString();
      }
    }
    return equipmentId.toString();
  }

  ({DateTime date, int hour, int minute, int equipmentId})? _resolveDropTarget({
    required DateTime date,
    required Offset localOffset,
    required double dayColumnWidth,
  }) {
    if (widget.equipmentList.isEmpty || widget.hours.isEmpty) {
      return null;
    }

    final totalGridHeight = hourRowHeight * widget.hours.length;
    final clampedX = localOffset.dx
        .clamp(0.0, dayColumnWidth - 0.001)
        .toDouble();
    final clampedY = localOffset.dy.clamp(0.0, totalGridHeight).toDouble();

    final equipmentIndex = (clampedX / slotPitch).floor().clamp(
      0,
      widget.equipmentList.length - 1,
    );
    final equipmentId = widget.equipmentList[equipmentIndex].id as int;

    final earliestMinutes = widget.hours.first * 60;
    final latestMinutes = widget.hours.last * 60;
    final rawMinutes = earliestMinutes + ((clampedY / hourRowHeight) * 60);
    final snappedMinutes = ((rawMinutes / 15).round() * 15).clamp(
      earliestMinutes,
      latestMinutes,
    );

    return (
      date: DateTime(date.year, date.month, date.day),
      hour: snappedMinutes ~/ 60,
      minute: snappedMinutes % 60,
      equipmentId: equipmentId,
    );
  }

  bool _isSameDropTarget(
    _ReservationDragData dragData,
    ({DateTime date, int hour, int minute, int equipmentId}) target,
  ) {
    final reservation = dragData.reservation;
    return _dateKey(reservation.date) == _dateKey(target.date) &&
        reservation.hour == target.hour &&
        reservation.minute == target.minute &&
        reservation.equipmentId == target.equipmentId;
  }

  Widget _buildDragHoverHighlight(
    DateTime date,
    Map<int, int> equipmentIndexById,
    Map<int, int> hourIndexByHour,
  ) {
    final target = _activeDragTarget;
    if (target == null || _dateKey(target.date) != _dateKey(date)) {
      return const SizedBox.shrink();
    }

    final equipmentIndex = equipmentIndexById[target.equipmentId];
    final hourIndex = hourIndexByHour[target.hour];
    if (equipmentIndex == null || hourIndex == null) {
      return const SizedBox.shrink();
    }

    final topOffset =
        (hourIndex * hourRowHeight) + ((target.minute / 60.0) * hourRowHeight);

    return Positioned(
      top: topOffset,
      left: (equipmentIndex * slotPitch) + slotHorizontalMargin,
      width: slotWidth,
      height: hourRowHeight / 4,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: kBrandAccentColor.withValues(alpha: 0.2),
            border: Border.all(color: kBrandAccentColor, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmReservationMove(
    BuildContext context,
    Reservation reservation,
    ({DateTime date, int hour, int minute, int equipmentId}) target,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rezervasyon taşınsın mı?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('From:'),
            Text(
              '${_formatDragDate(reservation.date)} ${_formatDragTime(reservation.hour, reservation.minute)} - ${_equipmentNameFor(reservation.equipmentId)}',
            ),
            const SizedBox(height: 12),
            const Text('To:'),
            Text(
              '${_formatDragDate(target.date)} ${_formatDragTime(target.hour, target.minute)} - ${_equipmentNameFor(target.equipmentId)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Taşı'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<String?> _askReservationMoveScope(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rezervasyonu Güncelle'),
        content: const Text(
          'Bu tekrarlı bir rezervasyon. Ne yapmak istiyorsunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('single'),
            child: const Text('Sadece Bu Rezervasyon'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('future'),
            child: const Text('Bu ve Gelecek Rezervasyonlar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReservationDrop(
    BuildContext context,
    _ReservationDragData dragData,
    ({DateTime date, int hour, int minute, int equipmentId}) target,
  ) async {
    final reservation = dragData.reservation;
    if (_isSameDropTarget(dragData, target)) {
      return;
    }

    final pageState = context.findAncestorStateOfType<_ReservationsPageState>();
    final ref = pageState?.ref;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    final confirmed = await _confirmReservationMove(
      context,
      reservation,
      target,
    );
    if (!confirmed || !mounted || !context.mounted) {
      return;
    }

    String updateScope = 'single';
    final recurrenceGroupId = reservation.recurrenceGroupId;
    if (recurrenceGroupId != null && recurrenceGroupId.isNotEmpty) {
      if (!mounted || !context.mounted) {
        return;
      }
      final scope = await _askReservationMoveScope(context);
      if (scope == null || !mounted) {
        return;
      }
      updateScope = scope;
    }

    final updatedReservation = Reservation(
      id: reservation.id,
      salonId: reservation.salonId,
      equipmentId: target.equipmentId,
      memberId: reservation.memberId,
      memberName: reservation.memberName,
      memberTypeId: reservation.memberTypeId,
      memberTypeName: reservation.memberTypeName,
      memberTypeColor: reservation.memberTypeColor,
      date: target.date,
      hour: target.hour,
      minute: target.minute,
      recurrenceGroupId: reservation.recurrenceGroupId,
      recurrenceType: reservation.recurrenceType,
      recurrenceEndDate: reservation.recurrenceEndDate,
    );

    if (ref == null) {
      return;
    }

    final errorMessage = await ref
        .read(reservationsProvider.notifier)
        .updateReservation(
          updatedReservation,
          widget.token,
          repeatWeekly:
              reservation.recurrenceGroupId != null &&
              reservation.recurrenceGroupId!.isNotEmpty,
          updateScope: updateScope,
        );

    if (!mounted) {
      return;
    }

    if (errorMessage != null) {
      scaffoldMessenger?.showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      return;
    }

    scaffoldMessenger?.showSnackBar(
      const SnackBar(content: Text('Rezervasyon taşındı.')),
    );
    if (pageState != null) {
      await pageState._refreshReservationsDataQuick();
    }
  }

  Widget _buildReservationCard({
    required bool belongsToSelectedInstructor,
    required Color chipColor,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: belongsToSelectedInstructor
            ? chipColor.withOpacity(0.75)
            : Colors.black,
        border: Border.all(
          color: belongsToSelectedInstructor ? chipColor : Colors.black,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        label.length > 6 ? '${label.substring(0, 6)}…' : label,
        style: TextStyle(
          color: belongsToSelectedInstructor ? kBrandTextColor : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDateCell(
    BuildContext context,
    DateTime date,
    int hour,
    Set<String> slotStartSet,
  ) {
    final loc = AppLocalizations.of(context);
    final slots = <Widget>[];
    for (final equipment in widget.equipmentList) {
      final hasStartReservation = slotStartSet.contains(
        _slotStartKey(
          salonId: widget.salonId,
          date: date,
          hour: hour,
          equipmentId: equipment.id,
        ),
      );
      if (!hasStartReservation) {
        slots.add(
          InkWell(
            onTap: () async {
              final result = await showDialog(
                context: context,
                builder: (ctx) => ReservationFormDialog(
                  initialDate: date,
                  initialHour: hour,
                  salonId: widget.salonId,
                  equipmentId: equipment.id,
                  members: List<Member>.from(widget.members),
                  token: widget.token,
                  role: widget.role,
                  assignedSalonIds: widget.role == 'admin'
                      ? []
                      : (context
                                .findAncestorWidgetOfExactType<
                                  ReservationsPage
                                >()
                                ?.assignedSalonIds ??
                            []),
                ),
              );
              if (result != null) {
                final isSuccess =
                    result is String && result.startsWith('success:');
                if (isSuccess && mounted) {
                  final pageState = context
                      .findAncestorStateOfType<_ReservationsPageState>();
                  if (pageState != null) {
                    await pageState._refreshReservationsDataQuick();
                  }
                }
                final message = isSuccess
                    ? (loc?.translate('add') ?? 'Reservation created!')
                    : (result is String
                          ? '${loc?.translate('error') ?? 'Error'}: $result'
                          : (loc?.translate('error') ?? 'Error'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: isSuccess ? kBrandAccentColor : Colors.red,
                  ),
                );
              }
            },
            child: Container(
              height: hourRowHeight,
              width: slotWidth,
              margin: const EdgeInsets.symmetric(
                horizontal: slotHorizontalMargin,
              ),
              decoration: BoxDecoration(
                color: kBrandBackgroundColor,
                border: Border.all(color: kBrandAccentColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.add, color: kBrandAccentColor, size: 16),
                ),
              ),
            ),
          ),
        );
      } else {
        slots.add(
          Container(
            height: hourRowHeight,
            width: slotWidth,
            margin: const EdgeInsets.symmetric(
              horizontal: slotHorizontalMargin,
            ),
            decoration: BoxDecoration(
              color: kBrandBackgroundColor,
              border: Border.all(color: kBrandAccentColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }
    }
    return Row(children: slots);
  }

  Widget _buildDateReservationsOverlay(
    BuildContext context,
    DateTime date,
    Map<String, List<dynamic>> reservationsByDay,
    Map<int, int> equipmentIndexById,
    Map<int, int> hourIndexByHour,
    Map<int, Member> memberById,
  ) {
    final dayReservations = <dynamic>[];
    for (final reservation in reservationsByDay[_dateKey(date)] ?? const []) {
      if (reservation.salonId == widget.salonId) {
        dayReservations.add(reservation);
      }
    }
    dayReservations.sort((a, b) {
      if (a.hour != b.hour) return a.hour.compareTo(b.hour);
      final aMinute = a.minute is int
          ? a.minute as int
          : int.tryParse(a.minute.toString()) ?? 0;
      final bMinute = b.minute is int
          ? b.minute as int
          : int.tryParse(b.minute.toString()) ?? 0;
      return aMinute.compareTo(bMinute);
    });

    final reservationHeight =
        (reservationDurationMinutes / 60.0) * hourRowHeight;

    return Stack(
      clipBehavior: Clip.none,
      children: dayReservations.map<Widget>((reservation) {
        final equipmentIndex = equipmentIndexById[reservation.equipmentId];
        if (equipmentIndex == null) return const SizedBox.shrink();

        final hourIndex = hourIndexByHour[reservation.hour];
        if (hourIndex == null) return const SizedBox.shrink();

        final reservationMember = memberById[reservation.memberId];

        final isInstructorFilterActive = widget.selectedInstructorId != null;
        final belongsToSelectedInstructor =
            !isInstructorFilterActive ||
            (reservationMember != null &&
                reservationMember.assignedInstructorId ==
                    widget.selectedInstructorId);

        final int minute = reservation.minute is int
            ? reservation.minute as int
            : int.tryParse(reservation.minute.toString()) ?? 0;
        final safeMinute = minute < 0 ? 0 : (minute > 59 ? 59 : minute);
        final topOffset =
            (hourIndex * hourRowHeight) + ((safeMinute / 60.0) * hourRowHeight);

        Color chipColor = Colors.black;
        String label = 'Busy';

        if (belongsToSelectedInstructor) {
          chipColor = kBrandAccentColor;
          label = reservation.memberName.isNotEmpty
              ? reservation.memberName.split(' ').first
              : '-';

          if (reservation.memberTypeColor.isNotEmpty) {
            try {
              final hex = reservation.memberTypeColor.replaceAll('#', '');
              chipColor = Color(int.parse('FF$hex', radix: 16));
            } catch (_) {
              chipColor = kBrandAccentColor;
            }
          }
        }

        return Positioned(
          top: topOffset,
          left: (equipmentIndex * slotPitch) + slotHorizontalMargin,
          width: slotWidth,
          height: reservationHeight,
          child: LongPressDraggable<_ReservationDragData>(
            data: _ReservationDragData(reservation: reservation as Reservation),
            onDragEnd: (_) {
              _clearActiveDragTarget();
            },
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: slotWidth,
                height: reservationHeight,
                child: _buildReservationCard(
                  belongsToSelectedInstructor: belongsToSelectedInstructor,
                  chipColor: chipColor,
                  label: label,
                ),
              ),
            ),
            childWhenDragging: _buildReservationCard(
              belongsToSelectedInstructor: belongsToSelectedInstructor,
              chipColor: chipColor,
              label: label,
            ),
            child: GestureDetector(
              onTap: () async {
                final String? deleteScope = await showDialog<String>(
                  context: context,
                  builder: (ctx) => ReservationDetailDialog(
                    reservation: reservation,
                    onEdit: () async {
                      Navigator.of(ctx).pop();
                      final result = await showDialog(
                        context: context,
                        builder: (ctx2) => ReservationFormDialog(
                          initialReservation: reservation,
                          initialDate: reservation.date,
                          initialHour: reservation.hour,
                          salonId: reservation.salonId,
                          equipmentId: reservation.equipmentId,
                          members: List<Member>.from(widget.members),
                          token: widget.token,
                          role: widget.role,
                          assignedSalonIds: widget.isAdmin
                              ? []
                              : (context
                                        .findAncestorWidgetOfExactType<
                                          ReservationsPage
                                        >()
                                        ?.assignedSalonIds ??
                                    []),
                        ),
                      );
                      if (result != null &&
                          result.toString().startsWith('success:')) {
                        final pageState = context
                            .findAncestorStateOfType<_ReservationsPageState>();
                        if (pageState != null && mounted) {
                          await pageState._refreshReservationsDataQuick();
                        }
                      }
                    },
                  ),
                );
                if (deleteScope == 'single' || deleteScope == 'future') {
                  final pageState = context
                      .findAncestorStateOfType<_ReservationsPageState>();
                  final ref = pageState?.ref;
                  if (ref != null && deleteScope != null) {
                    final errorMessage = await ref
                        .read(reservationsProvider.notifier)
                        .deleteReservation(
                          reservation.id,
                          widget.token,
                          deleteScope: deleteScope,
                        );
                    if (errorMessage != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else if (pageState != null && mounted) {
                      await pageState._refreshReservationsDataQuick();
                    }
                  }
                }
              },
              child: _buildReservationCard(
                belongsToSelectedInstructor: belongsToSelectedInstructor,
                chipColor: chipColor,
                label: label,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final separatorColor = kBrandTextColor.withOpacity(0.12);
    const daySeparatorColor = kBrandAccentColor;
    const daySeparatorWidth = 2.0;
    final headerHeight = widget.compactLayout ? 52.0 : 64.0;
    final totalGridHeight = hourRowHeight * widget.hours.length;
    final Map<int, Member> memberById = <int, Member>{};
    for (final member in widget.members) {
      memberById.putIfAbsent(member.id, () => member);
    }
    final Map<int, int> equipmentIndexById = <int, int>{};
    for (final entry in widget.equipmentList.asMap().entries) {
      equipmentIndexById.putIfAbsent(entry.value.id, () => entry.key);
    }
    final Map<int, int> hourIndexByHour = <int, int>{};
    for (final entry in widget.hours.asMap().entries) {
      hourIndexByHour.putIfAbsent(entry.value, () => entry.key);
    }
    final Map<String, List<dynamic>> reservationsByDay =
        <String, List<dynamic>>{};
    final Set<String> slotStartSet = <String>{};
    for (final reservation in widget.reservations) {
      final dateKey = _dateKey(reservation.date);
      reservationsByDay
          .putIfAbsent(dateKey, () => <dynamic>[])
          .add(reservation);
      slotStartSet.add(
        _slotStartKey(
          salonId: reservation.salonId,
          date: reservation.date,
          hour: reservation.hour,
          equipmentId: reservation.equipmentId,
        ),
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: headerHeight,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: kBrandAccentColor.withOpacity(0.2),
                border: Border(bottom: BorderSide(color: separatorColor)),
              ),
              child: Text(
                loc?.translate('hour') ?? 'Hour',
                style: const TextStyle(
                  color: kBrandTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _headerHorizontalController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.dates.asMap().entries.map((entry) {
                    final date = entry.value;
                    final dayColumnWidth =
                        (widget.equipmentList.length * slotPitch) < slotPitch
                        ? slotPitch + slotHorizontalMargin
                        : (widget.equipmentList.length * slotPitch).toDouble() +
                              slotHorizontalMargin;
                    final weekday = [
                      'Pzt',
                      'Sal',
                      'Çar',
                      'Per',
                      'Cum',
                      'Cmt',
                      'Paz',
                    ][date.weekday - 1];
                    return Container(
                      width: dayColumnWidth,
                      height: headerHeight,
                      decoration: BoxDecoration(
                        color: kBrandAccentColor.withOpacity(0.2),
                        border: Border(
                          bottom: BorderSide(color: separatorColor),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '$weekday\n${DateFormat('dd/MM').format(date)}',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kBrandTextColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: dayColumnWidth - daySeparatorWidth,
                            width: daySeparatorWidth,
                            child: ColoredBox(color: daySeparatorColor),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh ?? () async {},
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: widget.compactLayout ? 24 : 96),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: widget.hours.map((hour) {
                      return Container(
                        width: 72,
                        height: hourRowHeight,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: separatorColor),
                            bottom: BorderSide(color: separatorColor),
                          ),
                        ),
                        child: Text(
                          '${hour.toString().padLeft(2, '0')}:00',
                          style: const TextStyle(color: kBrandTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                        ),
                      );
                    }).toList(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _bodyHorizontalController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.dates.map((date) {
                          final dayColumnWidth =
                              (widget.equipmentList.length * slotPitch) <
                                  slotPitch
                              ? slotPitch + slotHorizontalMargin
                              : (widget.equipmentList.length * slotPitch)
                                        .toDouble() +
                                    slotHorizontalMargin;
                          return Builder(
                            builder: (dayContext) {
                              return DragTarget<_ReservationDragData>(
                                onMove: (details) {
                                  final box =
                                      dayContext.findRenderObject()
                                          as RenderBox?;
                                  if (box == null) return;
                                  _setActiveDragTarget(
                                    _resolveDropTarget(
                                      date: date,
                                      localOffset: box.globalToLocal(
                                        details.offset,
                                      ),
                                      dayColumnWidth: dayColumnWidth,
                                    ),
                                  );
                                },
                                onLeave: (_) {
                                  _clearActiveDragTarget();
                                },
                                onWillAcceptWithDetails: (details) {
                                  final box =
                                      dayContext.findRenderObject()
                                          as RenderBox?;
                                  if (box == null) return false;
                                  return _resolveDropTarget(
                                        date: date,
                                        localOffset: box.globalToLocal(
                                          details.offset,
                                        ),
                                        dayColumnWidth: dayColumnWidth,
                                      ) !=
                                      null;
                                },
                                onAcceptWithDetails: (details) {
                                  final box =
                                      dayContext.findRenderObject()
                                          as RenderBox?;
                                  if (box == null) return;
                                  final target =
                                      _activeDragTarget ??
                                      _resolveDropTarget(
                                        date: date,
                                        localOffset: box.globalToLocal(
                                          details.offset,
                                        ),
                                        dayColumnWidth: dayColumnWidth,
                                      );
                                  _clearActiveDragTarget();
                                  if (target == null ||
                                      _isSameDropTarget(details.data, target)) {
                                    return;
                                  }
                                  _handleReservationDrop(
                                    context,
                                    details.data,
                                    target,
                                  );
                                },
                                builder:
                                    (context, candidateData, rejectedData) {
                                      return SizedBox(
                                        width: dayColumnWidth,
                                        height: totalGridHeight,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Column(
                                              children: widget.hours.map((
                                                hour,
                                              ) {
                                                return Container(
                                                  width: dayColumnWidth,
                                                  height: hourRowHeight,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      right: BorderSide(
                                                        color: separatorColor,
                                                      ),
                                                      bottom: BorderSide(
                                                        color: separatorColor,
                                                      ),
                                                    ),
                                                  ),
                                                  child: _buildDateCell(
                                                    context,
                                                    date,
                                                    hour,
                                                    slotStartSet,
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            _buildDragHoverHighlight(
                                              date,
                                              equipmentIndexById,
                                              hourIndexByHour,
                                            ),
                                            _buildDateReservationsOverlay(
                                              context,
                                              date,
                                              reservationsByDay,
                                              equipmentIndexById,
                                              hourIndexByHour,
                                              memberById,
                                            ),
                                            Positioned(
                                              top: 0,
                                              bottom: 0,
                                              left:
                                                  dayColumnWidth -
                                                  daySeparatorWidth,
                                              width: daySeparatorWidth,
                                              child: ColoredBox(
                                                color: daySeparatorColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReservationsPageState extends ConsumerState<ReservationsPage> {
  final Map<int, String> _instructorNamesById = {};
  int? _selectedInstructorId;

  String _formatLocalDate(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  ({String startDate, String endDate}) _currentVisibleDateRange() {
    if (_viewMode == 'Daily') {
      final day = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final formatted = _formatLocalDate(day);
      return (startDate: formatted, endDate: formatted);
    }

    if (_viewMode == 'Weekly') {
      final start = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ).subtract(Duration(days: _selectedDate.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return (
        startDate: _formatLocalDate(start),
        endDate: _formatLocalDate(end),
      );
    }

    final monthStart = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final monthEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    return (
      startDate: _formatLocalDate(monthStart),
      endDate: _formatLocalDate(monthEnd),
    );
  }

  Future<void> _fetchReservationsForVisibleRange() async {
    final range = _currentVisibleDateRange();
    await ref
        .read(reservationsProvider.notifier)
        .fetchReservations(
          widget.token,
          startDate: range.startDate,
          endDate: range.endDate,
        );
  }

  Future<void> _refreshReservationsDataFull({
    bool onlyIfEmpty = false,
    bool forceReservations = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    print('[PERF] reservations page full refresh start');
    try {
      if (!onlyIfEmpty || ref.read(salonsProvider).salons.isEmpty) {
        await ref.read(salonsProvider.notifier).fetchSalons();
      }
      if (!onlyIfEmpty || ref.read(equipmentProvider).equipmentList.isEmpty) {
        await ref.read(equipmentProvider.notifier).fetchEquipment();
      }
      if (!onlyIfEmpty || ref.read(memberProvider).members.isEmpty) {
        await ref.read(memberProvider.notifier).fetchMembers(widget.token);
      }
      if (forceReservations ||
          !onlyIfEmpty ||
          ref.read(reservationsProvider).reservations.isEmpty) {
        await _fetchReservationsForVisibleRange();
      }
      await _fetchInstructorNames();
    } finally {
      print(
        '[PERF] reservations page full refresh done: ${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  Future<void> _refreshReservationsDataQuick() async {
    final stopwatch = Stopwatch()..start();
    print('[PERF] reservations page quick refresh start');
    final salonsMissing = ref.read(salonsProvider).salons.isEmpty;
    final equipmentMissing = ref.read(equipmentProvider).equipmentList.isEmpty;
    final membersMissing = ref.read(memberProvider).members.isEmpty;

    try {
      if (salonsMissing || equipmentMissing || membersMissing) {
        await _refreshReservationsDataFull(
          onlyIfEmpty: true,
          forceReservations: true,
        );
        return;
      }

      await _fetchReservationsForVisibleRange();
    } finally {
      print(
        '[PERF] reservations page quick refresh done: ${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final ref = this.ref;
      final currentSalons = ref.read(salonsProvider).salons;
      if (mounted && _selectedSalonId == null && currentSalons.isNotEmpty) {
        setState(() {
          if (widget.role == 'admin') {
            _selectedSalonId = currentSalons.first.id;
          } else {
            final allowed = currentSalons
                .where((s) => widget.assignedSalonIds.contains(s.id))
                .toList();
            _selectedSalonId = allowed.isNotEmpty
                ? allowed.first.id
                : currentSalons.first.id;
          }
        });
      }

      final initialRefreshStopwatch = Stopwatch()..start();
      print('[PERF] reservations page initial refresh start');
      await _refreshReservationsDataFull(onlyIfEmpty: true);
      print(
        '[PERF] reservations page initial refresh done: ${initialRefreshStopwatch.elapsedMilliseconds}ms',
      );
      final salons = ref.read(salonsProvider).salons;
      if (mounted && _selectedSalonId == null && salons.isNotEmpty) {
        setState(() {
          if (widget.role == 'admin') {
            _selectedSalonId = salons.first.id;
          } else {
            // instructor: pick first allowed salon
            final allowed = salons
                .where((s) => widget.assignedSalonIds.contains(s.id))
                .toList();
            if (allowed.isNotEmpty) {
              _selectedSalonId = allowed.first.id;
            } else {
              _selectedSalonId = salons.first.id;
            }
          }
        });
      }
    });
  }

  Future<void> _fetchInstructorNames() async {
    try {
      final response = await http.get(
        Uri.parse('http://204.168.168.23:3000/settings/users/instructors'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return;

      final Map<int, String> names = {};

      for (final item in decoded) {
        if (item is Map<String, dynamic> && item['role'] == 'instructor') {
          final id = item['id'];
          final username = item['username'];
          final name = item['name'];

          if (id is int) {
            final displayName = (name ?? username)?.toString().trim();
            if (displayName != null && displayName.isNotEmpty) {
              names[id] = displayName;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _instructorNamesById
          ..clear()
          ..addAll(names);
      });
    } catch (_) {
      // Keep ID fallback if instructor fetch fails.
    }
  }

  DateTime _selectedDate = DateTime.now();
  final List<int> _hours = List.generate(16, (i) => 7 + i); // 07:00 - 22:00
  String _viewMode = 'Weekly';
  int? _selectedSalonId;
  List<DateTime> get dates {
    if (_viewMode == 'Daily') {
      return [_selectedDate];
    } else if (_viewMode == 'Weekly') {
      final startOfWeek = _selectedDate.subtract(
        Duration(days: _selectedDate.weekday - 1),
      );
      return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    } else {
      // Monthly
      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final nextMonth = DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        1,
      );
      final daysInMonth = nextMonth.difference(firstDay).inDays;
      return List.generate(daysInMonth, (i) => firstDay.add(Duration(days: i)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final loc = AppLocalizations.of(context);
    const allLabel = 'Tümü';
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final salonsState = ref.watch(salonsProvider);
    final equipmentState = ref.watch(equipmentProvider);
    final reservationsState = ref.watch(reservationsProvider);
    final membersState = ref.watch(memberProvider);

    String instructorLabel(int id) {
      return _instructorNamesById[id] ??
          '${loc?.translate('instructorId') ?? 'Eğitmen ID'} $id';
    }

    final salons = salonsState.salons;
    final hasSalons = salons.isNotEmpty;
    final hasEquipment = equipmentState.equipmentList.isNotEmpty;
    final hasMembers = membersState.members.isNotEmpty;
    final hasReservations = reservationsState.reservations.isNotEmpty;
    final hasAnyExistingData =
        hasSalons || hasEquipment || hasMembers || hasReservations;
    final isInitialLoading =
        !hasAnyExistingData &&
        (salonsState.isLoading ||
            equipmentState.isLoading ||
            membersState.status == MemberStatus.loading ||
            reservationsState.isLoading);
    final equipmentList = _selectedSalonId == null
        ? []
        : equipmentState.equipmentList
              .where((e) => e.salonId == _selectedSalonId)
              .toList();
    // Build unique instructor IDs from members
    final instructorIds =
        membersState.members
            .map((m) => m.assignedInstructorId)
            .where((id) => id != null)
            .cast<int>()
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      backgroundColor: kBrandBackgroundColor,
      appBar: isLandscape
          ? null
          : AppBar(
              toolbarHeight: 46,
              backgroundColor: const Color(0xFF116478),
              iconTheme: const IconThemeData(color: Colors.white),
              title: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc?.translate('reservations') ?? 'Reservations',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    _refreshReservationsDataQuick();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip:
                      loc?.translate('addReservation') ?? 'Add Reservation',
                  onPressed: () async {
                    if (_selectedSalonId == null) return;
                    final members = membersState.members;
                    print(
                      '[Reservation Add] Passing members to dialog: count = \\${members.length}',
                    );
                    final result = await showDialog(
                      context: context,
                      builder: (ctx) => ReservationFormDialog(
                        initialDate: null,
                        initialHour: null,
                        salonId: _selectedSalonId!,
                        equipmentId: equipmentList.isNotEmpty
                            ? equipmentList.first.id
                            : 0,
                        members: members,
                        token: widget.token,
                        role: widget.role,
                        assignedSalonIds: widget.role == 'admin'
                            ? []
                            : widget.assignedSalonIds,
                      ),
                    );
                    if (result != null) {
                      final isSuccess =
                          result is String && result.startsWith('success:');
                      if (isSuccess) {
                        await _refreshReservationsDataQuick();
                      }
                      final message = isSuccess
                          ? (loc?.translate('reservationCreated') ??
                                'Reservation created!')
                          : (result is String
                                ? '${loc?.translate('error') ?? 'Error'}: $result'
                                : (loc?.translate('error') ?? 'Error'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: isSuccess
                              ? kBrandAccentColor
                              : Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
              elevation: 0,
            ),
      body: SafeArea(
        top: isLandscape,
        bottom: false,
        child: isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : salonsState.error != null && salons.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${loc?.translate('error') ?? 'Error'}: ${salonsState.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(salonsProvider.notifier).fetchSalons();
                        },
                        child: Text(loc?.translate('retry') ?? 'Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : salons.isEmpty
            ? Center(
                child: Text(
                  loc?.translate('noSalonFound') ?? 'Salon bulunamadı',
                  style: const TextStyle(color: kBrandTextColor),
                ),
              )
            : Column(
                children: [
                  // View mode switcher and salon selector
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      isLandscape ? 2 : 4,
                      8,
                      isLandscape ? 2 : 4,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 34,
                          child: ToggleButtons(
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 32,
                            ),
                            isSelected: [
                              _viewMode == 'Daily',
                              _viewMode == 'Weekly',
                              _viewMode == 'Monthly',
                            ],
                            onPressed: (idx) {
                              setState(() {
                                if (idx == 0) _viewMode = 'Daily';
                                if (idx == 1) _viewMode = 'Weekly';
                                if (idx == 2) _viewMode = 'Monthly';
                              });
                              _refreshReservationsDataQuick();
                            },
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 1,
                                ),
                                child: Text(
                                  loc?.translate('dailyShort') ?? 'G',
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 1,
                                ),
                                child: Text(
                                  loc?.translate('weeklyShort') ?? 'H',
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 1,
                                ),
                                child: Text(
                                  loc?.translate('monthlyShort') ?? 'A',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<int>(
                            value: _selectedSalonId,
                            isDense: true,
                            isExpanded: true,
                            hint: Text(
                              loc?.translate('selectSalon') ?? 'Select Salon',
                              style: const TextStyle(color: kBrandTextColor),
                            ),
                            items: salons
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(
                                      s.name,
                                      style: const TextStyle(
                                        color: kBrandTextColor,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (id) {
                              setState(() => _selectedSalonId = id);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: isLandscape ? 110 : 120,
                          child: DropdownButton<int?>(
                            value: _selectedInstructorId,
                            isDense: true,
                            hint: Text(
                              allLabel,
                              style: const TextStyle(color: kBrandTextColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  allLabel,
                                  style: const TextStyle(
                                    color: kBrandTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...instructorIds.map(
                                (id) => DropdownMenuItem<int?>(
                                  value: id,
                                  child: Text(
                                    instructorLabel(id),
                                    style: const TextStyle(
                                      color: kBrandTextColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedInstructorId = value),
                            isExpanded: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date selector
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 4 : 8.0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          iconSize: 22,
                          icon: const Icon(
                            Icons.chevron_left,
                            color: kBrandTextColor,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_viewMode == 'Daily') {
                                _selectedDate = _selectedDate.subtract(
                                  const Duration(days: 1),
                                );
                              } else if (_viewMode == 'Weekly') {
                                _selectedDate = _selectedDate.subtract(
                                  const Duration(days: 7),
                                );
                              } else {
                                // Monthly
                                _selectedDate = DateTime(
                                  _selectedDate.year,
                                  _selectedDate.month - 1,
                                  1,
                                );
                              }
                            });
                            _refreshReservationsDataQuick();
                          },
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              _viewMode == 'Monthly'
                                  ? '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}'
                                  : '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: kBrandTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          iconSize: 22,
                          icon: const Icon(
                            Icons.chevron_right,
                            color: kBrandTextColor,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_viewMode == 'Daily') {
                                _selectedDate = _selectedDate.add(
                                  const Duration(days: 1),
                                );
                              } else if (_viewMode == 'Weekly') {
                                _selectedDate = _selectedDate.add(
                                  const Duration(days: 7),
                                );
                              } else {
                                // Monthly
                                _selectedDate = DateTime(
                                  _selectedDate.year,
                                  _selectedDate.month + 1,
                                  1,
                                );
                              }
                            });
                            _refreshReservationsDataQuick();
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isLandscape ? 4 : 8),
                  Expanded(
                    child: _selectedSalonId == null
                        ? Center(
                            child: Text(
                              loc?.translate('selectSalon') ?? 'Select salon',
                              style: const TextStyle(color: kBrandTextColor),
                            ),
                          )
                        : (_viewMode == 'Daily'
                              ? Center(
                                  child: Consumer(
                                    builder: (context, ref, _) {
                                      final memberTypesState = ref.watch(
                                        memberTypesProvider,
                                      );
                                      final memberTypes =
                                          memberTypesState.memberTypes;
                                      return _EquipmentReservationGrid(
                                        dates: dates,
                                        hours: _hours,
                                        salonId: _selectedSalonId!,
                                        equipmentList: equipmentList,
                                        token: widget.token,
                                        role: widget.role,
                                        reservations:
                                            reservationsState.reservations,
                                        members: membersState.members,
                                        memberTypes: memberTypes,
                                        isAdmin: widget.role == 'admin',
                                        selectedInstructorId:
                                            _selectedInstructorId,
                                        compactLayout: isLandscape,
                                        onRefresh:
                                            _refreshReservationsDataQuick,
                                      );
                                    },
                                  ),
                                )
                              : Consumer(
                                  builder: (context, ref, _) {
                                    final memberTypesState = ref.watch(
                                      memberTypesProvider,
                                    );
                                    final memberTypes =
                                        memberTypesState.memberTypes;
                                    return _EquipmentReservationGrid(
                                      dates: dates,
                                      hours: _hours,
                                      salonId: _selectedSalonId!,
                                      equipmentList: equipmentList,
                                      token: widget.token,
                                      role: widget.role,
                                      reservations:
                                          reservationsState.reservations,
                                      members: membersState.members,
                                      memberTypes: memberTypes,
                                      isAdmin: widget.role == 'admin',
                                      selectedInstructorId:
                                          _selectedInstructorId,
                                      compactLayout: isLandscape,
                                      onRefresh: _refreshReservationsDataQuick,
                                    );
                                  },
                                )),
                  ),
                ],
              ),
      ),
    );
  }
}
