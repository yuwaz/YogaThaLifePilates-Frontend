import 'reservations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reservation.dart';
import '../models/member.dart';
import '../providers/reservation_provider.dart';
import '../l10n/app_localizations.dart';

class ReservationFormDialog extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final int? initialHour;
  final int salonId;
  final int equipmentId;
  final List<Member> members;
  final String token;
  final String role;
  final List<int> assignedSalonIds;
  final Reservation? initialReservation;

  const ReservationFormDialog({
    Key? key,
    this.initialDate,
    this.initialHour,
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
  bool get isEditingRecurring =>
      widget.initialReservation?.recurrenceGroupId != null &&
      widget.initialReservation!.recurrenceGroupId!.isNotEmpty;
  bool _repeatWeekly = false;
  int? _selectedMemberId;
  final GlobalKey _memberFieldKey = GlobalKey();
  late DateTime? _selectedDate;
  late int? _selectedHour;
  late int _selectedMinute;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialReservation?.date ?? widget.initialDate;
    _selectedHour = widget.initialReservation?.hour ?? widget.initialHour;
    _selectedMinute = widget.initialReservation?.minute ?? 0;

    // Set _repeatWeekly based on recurrenceGroupId for edit mode
    if (widget.initialReservation != null &&
        widget.initialReservation!.recurrenceGroupId != null &&
        widget.initialReservation!.recurrenceGroupId.toString().isNotEmpty) {
      _repeatWeekly = true;
    } else {
      _repeatWeekly = false;
    }

    // If editing, use the reservation's memberId. Otherwise, auto-select if only one member.
    if (widget.initialReservation?.memberId != null) {
      _selectedMemberId = widget.initialReservation!.memberId;
    } else {
      // Only filter by assignedSalonIds
      final filteredMembers = widget.members
          .where((m) => m.assignedSalonIds.contains(widget.salonId))
          .toList();
      if (filteredMembers.length == 1) {
        _selectedMemberId = filteredMembers.first.id;
        // ignore: avoid_print
        print(
          '[Reservation Dialog] Auto-selected member id: \\${_selectedMemberId}',
        );
      } else {
        _selectedMemberId = null;
      }
    }
  }

  String _normalizeSearchText(String value) {
    const replacements = {
      'I': 'i',
      'İ': 'i',
      'ı': 'i',
      'Ş': 's',
      'ş': 's',
      'Ğ': 'g',
      'ğ': 'g',
      'Ü': 'u',
      'ü': 'u',
      'Ö': 'o',
      'ö': 'o',
      'Ç': 'c',
      'ç': 'c',
    };

    final normalized = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      normalized.write(replacements[char] ?? char.toLowerCase());
    }
    return normalized.toString();
  }

  bool _matchesMemberSearch(Member member, String query) {
    final normalizedQuery = _normalizeSearchText(query.trim());
    if (normalizedQuery.isEmpty) return true;

    final name = _normalizeSearchText(member.name);
    final phone = _normalizeSearchText(member.phone);
    final email = _normalizeSearchText(member.email);
    return name.contains(normalizedQuery) ||
        phone.contains(normalizedQuery) ||
        email.contains(normalizedQuery);
  }

  Future<void> _openMemberDropdownMenu(List<Member> salonMembers) async {
    final memberFieldContext = _memberFieldKey.currentContext;
    if (memberFieldContext == null) return;

    final renderBox = memberFieldContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final fieldSize = renderBox.size;
    final fieldOffset = renderBox.localToGlobal(Offset.zero);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final selectedMemberId = await showMenu<int>(
      context: context,
      color: kBrandBackgroundColor,
      elevation: 6,
      menuPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      constraints: BoxConstraints.tightFor(width: fieldSize.width),
      position: RelativeRect.fromLTRB(
        fieldOffset.dx,
        fieldOffset.dy + fieldSize.height,
        overlay.size.width - (fieldOffset.dx + fieldSize.width),
        0,
      ),
      items: [
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _MemberDropdownSearchContent(
            members: salonMembers,
            width: fieldSize.width,
            selectedMemberId: _selectedMemberId,
            matchesSearch: _matchesMemberSearch,
          ),
        ),
      ],
    );

    if (!mounted || selectedMemberId == null) return;
    setState(() {
      _selectedMemberId = selectedMemberId;
    });
  }

  bool get _canSubmit {
    if (_selectedMemberId == null) return false;
    if (_selectedDate == null || _selectedHour == null) return false;
    // Do NOT disable for past date; allow button to be pressed
    if (widget.salonId == 0 || widget.equipmentId == 0) return false;
    if (widget.role == 'instructor' &&
        !widget.assignedSalonIds.contains(widget.salonId))
      return false;
    return true;
  }

  Future<void> _submit() async {
    // Check for past date/time before submitting
    final now = DateTime.now();
    if (_selectedDate != null && _selectedHour != null) {
      final selectedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedHour!,
        _selectedMinute,
      );
      if (selectedDateTime.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçmiş tarihe rezervasyon yapılamaz.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    print(
      '[Reservation Dialog] Submitting with selected member id: \\${_selectedMemberId}',
    );
    final member = widget.members.firstWhere((m) => m.id == _selectedMemberId);
    final isEdit = widget.initialReservation != null;
    final reservation = Reservation(
      id: isEdit ? widget.initialReservation!.id : 0,
      date: _selectedDate!,
      hour: _selectedHour!,
      minute: _selectedMinute,
      salonId: widget.salonId,
      equipmentId: widget.equipmentId,
      memberId: member.id,
      memberName: member.name,
      memberTypeId: member.memberTypeId,
      memberTypeName: member.memberTypeName,
      memberTypeColor: member.memberTypeColor,
    );
    print(
      '[Reservation Dialog] Submit payload: id=\\${reservation.id}, date=\\${reservation.date}, hour=\\${reservation.hour}, salonId=\\${reservation.salonId}, equipmentId=\\${reservation.equipmentId}, memberId=\\${reservation.memberId}, memberName=\\${reservation.memberName}',
    );
    String? result;
    if (isEdit) {
      String updateScope = 'single';
      final recurrenceGroupId = widget.initialReservation?.recurrenceGroupId;
      if (recurrenceGroupId != null &&
          recurrenceGroupId.toString().isNotEmpty) {
        final scope = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rezervasyonu Güncelle'),
            content: const Text(
              'Bu tekrarlı bir rezervasyon. Ne yapmak istiyorsunuz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('single'),
                child: const Text('Sadece Bu Rezervasyon'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('future'),
                child: const Text('Bu ve Gelecek Rezervasyonlar'),
              ),
            ],
          ),
        );
        if (scope == null) {
          setState(() => _isSubmitting = false);
          return;
        }
        updateScope = scope;
      }
      result = await ref
          .read(reservationsProvider.notifier)
          .updateReservation(
            reservation,
            widget.token,
            repeatWeekly: _repeatWeekly,
            updateScope: updateScope,
          );
    } else {
      result = await ref
          .read(reservationsProvider.notifier)
          .addReservation(
            reservation,
            widget.token,
            repeatWeekly: _repeatWeekly,
          );
    }
    setState(() => _isSubmitting = false);
    if (mounted) {
      if (result == null) {
        Navigator.of(
          context,
        ).pop(isEdit ? 'success:edited' : 'success:created');
      } else {
        // Check for past date error keywords
        final lower = result.toLowerCase();
        if (lower.contains('past date') ||
            lower.contains('geçmiş tarih') ||
            lower.contains('past reservation') ||
            lower.contains('date is in the past')) {
          setState(() {
            _errorText = 'Geçmiş tarihe rezervasyon yapılamaz.';
          });
        } else {
          setState(() {
            _errorText = result;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Filtering logic ---
    // Get salon type (Yoga/Pilates) for filtering

    // DEBUG: Print all relevant info
    // ignore: avoid_print
    print('[Reservation Dialog] Members received: \\${widget.members.length}');
    print('[Reservation Dialog] Selected salonId: \\${widget.salonId}');
    print('[Reservation Dialog] Selected equipmentId: \\${widget.equipmentId}');
    for (final m in widget.members) {
      print(
        '[Reservation Dialog] Member id: \\${m.id}, name: \\${m.name}, assignedSalonIds: \\${m.assignedSalonIds}',
      );
    }

    // Only filter by assignedSalonIds
    final salonMembers = widget.members.where((m) {
      return m.assignedSalonIds.contains(widget.salonId);
    }).toList();

    Member? selectedMember;
    if (_selectedMemberId != null) {
      for (final member in widget.members) {
        if (member.id == _selectedMemberId) {
          selectedMember = member;
          break;
        }
      }
    }

    print(
      '[Reservation Dialog] Filtered members count: \\${salonMembers.length}',
    );
    for (final m in salonMembers) {
      print(
        '[Reservation Dialog] Filtered member id: \\${m.id}, name: \\${m.name}',
      );
    }

    return AlertDialog(
      backgroundColor: kBrandBackgroundColor,
      title: Text(
        widget.initialReservation == null
            ? AppLocalizations.of(context)?.translate('addReservation') ??
                  'Add Reservation'
            : AppLocalizations.of(context)?.translate('editReservation') ??
                  'Edit Reservation',
        style: const TextStyle(color: kBrandTextColor),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: _memberFieldKey,
              borderRadius: BorderRadius.circular(8),
              onTap: salonMembers.isEmpty
                  ? null
                  : () => _openMemberDropdownMenu(salonMembers),
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kBrandBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedMember?.name ?? 'Üye Seç',
                        style: TextStyle(
                          color: selectedMember == null
                              ? kBrandTextColor.withOpacity(0.8)
                              : kBrandTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down, color: kBrandTextColor),
                  ],
                ),
              ),
            ),
            if (salonMembers.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Üye bulunamadı',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _repeatWeekly,
              onChanged: isEditingRecurring
                  ? null
                  : (value) {
                      setState(() {
                        _repeatWeekly = value ?? false;
                      });
                    },
              title: const Text(
                'Her hafta tekrarla',
                style: TextStyle(color: kBrandTextColor),
              ),
              subtitle: isEditingRecurring
                  ? const Text(
                      "Tekrarlı rezervasyonu bitirmek için silme ekranından 'Bu ve Gelecek Rezervasyonlar' seçeneğini kullanın.",
                      style: TextStyle(color: Colors.grey),
                    )
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            // Date picker
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: kBrandAccentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null)
                        setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: kBrandBackgroundColor,
                        border: Border.all(
                          color: kBrandAccentColor.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.year}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.day.toString().padLeft(2, '0')}'
                            : 'Tarih Seç',
                        style: const TextStyle(color: kBrandTextColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Time picker
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: kBrandAccentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedHour == null
                        ? null
                        : (_selectedHour! * 60 + _selectedMinute),
                    hint: const Text(
                      'Saat Seç',
                      style: TextStyle(color: kBrandTextColor),
                    ),
                    items: [
                      for (int h = 7; h <= 22; h++)
                        for (final m in const [0, 15, 30, 45])
                          if (!(h == 22 && m != 0))
                            DropdownMenuItem(
                              value: h * 60 + m,
                              child: Text(
                                '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: kBrandTextColor),
                              ),
                            ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedHour = value ~/ 60;
                        _selectedMinute = value % 60;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kBrandBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
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
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel',
            style: const TextStyle(color: kBrandTextColor),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandAccentColor,
            foregroundColor: kBrandTextColor,
          ),
          onPressed: (_isSubmitting || !_canSubmit) ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kBrandTextColor,
                  ),
                )
              : Text(
                  AppLocalizations.of(context)?.translate('save') ?? 'Save',
                  style: const TextStyle(color: kBrandTextColor),
                ),
        ),
      ],
    );
  }
}

class _MemberDropdownSearchContent extends StatefulWidget {
  final List<Member> members;
  final double width;
  final int? selectedMemberId;
  final bool Function(Member member, String query) matchesSearch;

  const _MemberDropdownSearchContent({
    required this.members,
    required this.width,
    required this.selectedMemberId,
    required this.matchesSearch,
  });

  @override
  State<_MemberDropdownSearchContent> createState() =>
      _MemberDropdownSearchContentState();
}

class _MemberDropdownSearchContentState
    extends State<_MemberDropdownSearchContent> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = widget.members
        .where((m) => widget.matchesSearch(m, _searchText))
        .toList();

    return SizedBox(
      width: widget.width,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
                style: const TextStyle(color: kBrandTextColor),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Üye ara...',
                  hintStyle: TextStyle(color: kBrandTextColor.withOpacity(0.7)),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchText = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: kBrandBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            Flexible(
              child: filteredMembers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Üye bulunamadı',
                        style: TextStyle(color: Colors.red),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      shrinkWrap: true,
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = filteredMembers[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          visualDensity: const VisualDensity(
                            vertical: -2,
                            horizontal: 0,
                          ),
                          title: Text(
                            member.name,
                            style: const TextStyle(color: kBrandTextColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: member.id == widget.selectedMemberId
                              ? const Icon(
                                  Icons.check,
                                  color: kBrandAccentColor,
                                  size: 18,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(member.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
