import '../models/member.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/member_provider.dart';
import '../providers/member_types_provider.dart';
import '../l10n/app_localizations.dart';
import 'member_attendance_details_page.dart';
import '../theme/app_design_tokens.dart';

class AttendancePage extends ConsumerStatefulWidget {
  final String token;
  final bool isAdmin;
  final List<int> instructorSalonIds;
  const AttendancePage({
    super.key,
    required this.token,
    required this.isAdmin,
    required this.instructorSalonIds,
  });

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage>
    with WidgetsBindingObserver {
  int _selectedTabIndex = 0;
  String _attendanceSearchQuery = '';
  Timer? _refreshTimer;
  Timer? _searchDebounce;
  bool _isRefreshing = false;
  List<Member> _filteredMembers = const [];
  List<Attendance> _filteredAttendanceHistory = const [];
  Map<int, Member> _memberById = const {};
  List<Member>? _lastMembersSource;
  List<Attendance>? _lastAttendanceSource;
  bool _needsAttendanceRecompute = true;

  Future<void> _refreshAttendance() async {
    if (!mounted || _isRefreshing) return;
    _isRefreshing = true;
    try {
      await ref.read(attendanceProvider.notifier).fetchAttendance(widget.token);
    } finally {
      _isRefreshing = false;
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _refreshAttendance();
    });
  }

  void _markAttendanceDirty() {
    _needsAttendanceRecompute = true;
  }

  Color _memberTypeColor(MemberType? memberType) {
    try {
      final hex = (memberType?.color ?? '').replaceAll('#', '');
      if (hex.isEmpty) {
        return AppDesignTokens.backgroundSecondary;
      }
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppDesignTokens.backgroundSecondary;
    }
  }

  void _recomputeAttendanceCaches(
    List<Member> members,
    List<Attendance> attendances,
  ) {
    _filteredMembers = members.where((member) {
      if (_attendanceSearchQuery.isEmpty) return true;

      final query = _attendanceSearchQuery;
      final name = member.name.toString().toLowerCase();
      final phone = member.phone.toString().toLowerCase();
      final email = member.email.toString().toLowerCase();

      return name.contains(query) ||
          phone.contains(query) ||
          email.contains(query);
    }).toList();

    _filteredAttendanceHistory =
        attendances.where((a) {
          if (_attendanceSearchQuery.isEmpty) return true;
          final name = _memberById[a.memberId]?.name.toLowerCase() ?? '';
          return name.contains(_attendanceSearchQuery);
        }).toList()..sort((a, b) {
          final dateCompare = b.date.compareTo(a.date);
          if (dateCompare != 0) return dateCompare;
          return b.id.compareTo(a.id);
        });

    _needsAttendanceRecompute = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAttendance();
    });
    _startAutoRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAttendance();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final loc = AppLocalizations.of(context);
    final attendanceState = ref.watch(attendanceProvider);
    final memberState = ref.watch(memberProvider);
    // Get member types list from provider (only here)
    final memberTypesState = ref.watch(memberTypesProvider);
    final memberTypes = memberTypesState.memberTypes;
    final memberTypeMap = {for (final type in memberTypes) type.id: type};

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        toolbarHeight: 46,
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        iconTheme: const IconThemeData(color: AppDesignTokens.textPrimary),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            loc?.translate('attendance') ?? 'Attendance',
            style: AppTypography.sectionTitle,
            textAlign: TextAlign.left,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.create),
            tooltip: loc?.translate('add') ?? 'Add',
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => _AddAttendanceDialog(
                  members: memberState.members
                      .where((m) => m.isActive)
                      .toList(),
                  token: token,
                  ref: ref,
                  memberTypes: memberTypes,
                ),
              );
              if (result == true) {
                await ref.read(memberProvider.notifier).fetchMembers(token);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      loc?.translate('attendanceMarked') ?? 'Attendance marked',
                    ),
                    backgroundColor: AppDesignTokens.success,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (attendanceState is AsyncLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (attendanceState is AsyncError) {
            return Center(
              child: Text(
                '${loc?.translate('error') ?? 'Error'}: ${attendanceState.error}',
                style: AppTypography.body.copyWith(
                  color: AppDesignTokens.error,
                ),
              ),
            );
          } else if (memberState.members.isEmpty) {
            return Center(
              child: Text(
                'Üye bulunamadı',
                style: AppTypography.body.copyWith(
                  color: AppDesignTokens.textMuted,
                ),
              ),
            );
          }
          final attendances = attendanceState.value ?? [];
          if (!identical(_lastMembersSource, memberState.members)) {
            _lastMembersSource = memberState.members;
            _memberById = {for (final m in memberState.members) m.id: m};
            _markAttendanceDirty();
          }
          if (!identical(_lastAttendanceSource, attendances)) {
            _lastAttendanceSource = attendances;
            _markAttendanceDirty();
          }
          if (_needsAttendanceRecompute) {
            _recomputeAttendanceCaches(memberState.members, attendances);
          }

          // Tab/segmented control (match Payments page)
          Widget tabBar = Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0
                            ? AppDesignTokens.primaryAction
                            : AppDesignTokens.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Üyeler',
                          style: TextStyle(
                            color: _selectedTabIndex == 0
                                ? AppDesignTokens.primaryActionForeground
                                : AppDesignTokens.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1
                            ? AppDesignTokens.primaryAction
                            : AppDesignTokens.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Yoklama Geçmişi',
                          style: TextStyle(
                            color: _selectedTabIndex == 1
                                ? AppDesignTokens.primaryActionForeground
                                : AppDesignTokens.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Üye ara',
                      prefixIcon: Icon(AppIcons.search),
                    ),
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 200),
                        () {
                          if (!mounted) return;
                          setState(() {
                            _attendanceSearchQuery = value.trim().toLowerCase();
                            _markAttendanceDirty();
                          });
                        },
                      );
                    },
                  ),
                ),
                tabBar,
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshAttendance,
                    child: _selectedTabIndex == 0
                        ? (_filteredMembers.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 120),
                                    Center(
                                      child: Text(
                                        'Üye bulunamadı',
                                        style: AppTypography.body,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 96),
                                  itemCount: _filteredMembers.length,
                                  itemBuilder: (context, idx) {
                                    final member = _filteredMembers[idx];
                                    final memberTypeColor = _memberTypeColor(
                                      memberTypeMap[member.memberTypeId
                                          .toString()],
                                    );
                                    return Card(
                                      color: AppDesignTokens.surface,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: memberTypeColor,
                                          child: Text(
                                            member.name.isNotEmpty
                                                ? member.name[0]
                                                : '?',
                                            style: TextStyle(
                                              color:
                                                  memberTypeColor
                                                          .computeLuminance() >
                                                      0.5
                                                  ? AppDesignTokens.textPrimary
                                                  : AppDesignTokens
                                                        .primaryActionForeground,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          member.name,
                                          style: AppTypography.cardTitle,
                                        ),
                                        subtitle: Text(
                                          'Kalan Ders: ${member.remainingLessons}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.caption,
                                        ),
                                        trailing: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12.0,
                                          ),
                                          child: IntrinsicWidth(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(
                                                AppIcons.create,
                                                size: 16,
                                              ),
                                              label: const Text('Yoklama Al'),
                                              style: AppButtonStyles.primary.copyWith(
                                                padding:
                                                    const WidgetStatePropertyAll(
                                                      EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8,
                                                      ),
                                                    ),
                                                minimumSize:
                                                    const WidgetStatePropertyAll(
                                                      Size(0, 36),
                                                    ),
                                              ),
                                              onPressed: () async {
                                                final result =
                                                    await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) =>
                                                          _AddAttendanceDialog(
                                                            members: memberState
                                                                .members,
                                                            token: token,
                                                            ref: ref,
                                                            memberTypes:
                                                                memberTypes,
                                                            initialMember:
                                                                member,
                                                          ),
                                                    );
                                                if (result == true) {
                                                  await ref
                                                      .read(
                                                        attendanceProvider
                                                            .notifier,
                                                      )
                                                      .fetchAttendance(token);
                                                  await ref
                                                      .read(
                                                        memberProvider.notifier,
                                                      )
                                                      .fetchMembers(token);
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        loc?.translate(
                                                              'attendanceMarked',
                                                            ) ??
                                                            'Attendance marked',
                                                      ),
                                                      backgroundColor:
                                                          AppDesignTokens
                                                              .success,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  MemberAttendanceDetailsPage(
                                                    memberId: member.id,
                                                    memberName: member.name,
                                                    token: token,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ))
                        : (() {
                            if (_filteredAttendanceHistory.isEmpty) {
                              return ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text(
                                      'Henüz yoklama kaydı yok',
                                      style: AppTypography.body,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 120),
                              itemCount: _filteredAttendanceHistory.length,
                              itemBuilder: (context, idx) {
                                final a = _filteredAttendanceHistory[idx];
                                final foundMember = _memberById[a.memberId];
                                final memberName =
                                    foundMember?.name ??
                                    'Üye ID: ${a.memberId}';
                                final dateStr =
                                    '${a.date.day.toString().padLeft(2, '0')}.${a.date.month.toString().padLeft(2, '0')}.${a.date.year}';
                                final timeStr =
                                    '${a.date.hour.toString().padLeft(2, '0')}:${a.date.minute.toString().padLeft(2, '0')}';
                                return Card(
                                  color: AppDesignTokens.surface,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        memberName.isNotEmpty
                                            ? memberName[0]
                                            : '?',
                                      ),
                                    ),
                                    title: Text(
                                      memberName,
                                      style: AppTypography.cardTitle,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: AppTypography.caption,
                                        ),
                                        Text(
                                          'Saat: $timeStr',
                                          style: AppTypography.caption.copyWith(
                                            color:
                                                AppDesignTokens.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          })(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

InputDecoration _attendanceInputDecoration(String label) {
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

class _AddAttendanceDialog extends StatefulWidget {
  final List members;
  final String token;
  final WidgetRef ref;
  final List memberTypes;
  final dynamic initialMember;
  const _AddAttendanceDialog({
    required this.members,
    required this.token,
    required this.ref,
    required this.memberTypes,
    this.initialMember,
    Key? key,
  }) : super(key: key);

  @override
  State<_AddAttendanceDialog> createState() => _AddAttendanceDialogState();
}

class _AddAttendanceDialogState extends State<_AddAttendanceDialog> {
  int? _selectedMemberId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _memberPreselected = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMember != null) {
      _selectedMemberId = widget.initialMember.id;
      _memberPreselected = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppDesignTokens.surface,
      title: Text(
        loc?.translate('addAttendance') ?? 'Add Attendance',
        style: AppTypography.sectionTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            value: _selectedMemberId,
            items: widget.members
                .map<DropdownMenuItem<int>>(
                  (member) => DropdownMenuItem(
                    value: member.id,
                    child: Text(member.name),
                  ),
                )
                .toList(),
            onChanged: _memberPreselected
                ? null
                : (value) => setState(() => _selectedMemberId = value),
            decoration: _attendanceInputDecoration(
              loc?.translate('member') ?? 'Member',
            ),
          ),
          ListTile(
            title: Text(
              _selectedDate.toString().split(' ')[0],
              style: AppTypography.body,
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          ListTile(
            title: Text(
              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
              style: AppTypography.body,
            ),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              int tempHour = _selectedTime.hour;
              int tempMinute = _selectedTime.minute;
              await showModalBottomSheet(
                context: context,
                builder: (context) {
                  return Container(
                    height: 250,
                    color: AppDesignTokens.surface,
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                    initialItem: tempHour,
                                  ),
                                  itemExtent: 32.0,
                                  onSelectedItemChanged: (int value) {
                                    tempHour = value;
                                  },
                                  children: List<Widget>.generate(24, (
                                    int index,
                                  ) {
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const Text(":", style: TextStyle(fontSize: 20)),
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                    initialItem: tempMinute,
                                  ),
                                  itemExtent: 32.0,
                                  onSelectedItemChanged: (int value) {
                                    tempMinute = value;
                                  },
                                  children: List<Widget>.generate(60, (
                                    int index,
                                  ) {
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          child: Text(loc?.translate('set') ?? 'Set'),
                          onPressed: () {
                            setState(() {
                              _selectedTime = TimeOfDay(
                                hour: tempHour,
                                minute: tempMinute,
                              );
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      actions: [
        OutlinedButton.icon(
          style: AppButtonStyles.secondary,
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(AppIcons.close, size: 18),
          label: Text(loc?.translate('cancel') ?? 'Cancel'),
        ),
        ElevatedButton.icon(
          style: AppButtonStyles.primary,
          onPressed: () async {
            if (_selectedMemberId == null) return;
            final dateTime = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              _selectedTime.hour,
              _selectedTime.minute,
            );
            final existingAttendances =
                widget.ref.read(attendanceProvider).value ?? [];
            final hasSameDayAttendance = existingAttendances.any((a) {
              return a.memberId == _selectedMemberId &&
                  a.date.year == dateTime.year &&
                  a.date.month == dateTime.month &&
                  a.date.day == dateTime.day;
            });

            if (hasSameDayAttendance) {
              final confirmDuplicate = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Tekrar yoklama alınsın mı?'),
                  content: const Text(
                    'Bu üye için bugün zaten yoklama alınmış. Yine de tekrar yoklama almak istiyor musunuz?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Vazgeç'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Evet, Yoklama Al'),
                    ),
                  ],
                ),
              );
              if (confirmDuplicate != true) {
                return;
              }
            }
            // Find the selected member's assignedSalonIds
            final member = widget.members.firstWhere(
              (m) => m.id == _selectedMemberId,
            );
            // --- Attendance eligibility logic update (memberType lookup, no provider) ---
            MemberType? memberType;
            try {
              memberType = widget.memberTypes.firstWhere(
                (t) => t.id.toString() == member.memberTypeId.toString(),
              );
            } catch (_) {
              memberType = null;
            }
            final isCardBased = memberType?.isCardBased == true;
            if (member.remainingLessons <= 0 && !isCardBased) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kalan ders yok, yoklama alınamaz.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            int? selectedSalonId;
            if (member.assignedSalonIds is List &&
                member.assignedSalonIds.isNotEmpty) {
              if (member.assignedSalonIds.length == 1) {
                selectedSalonId = member.assignedSalonIds.first;
              } else {
                selectedSalonId = member.assignedSalonIds.first;
              }
            } else {
              selectedSalonId = null;
            }
            final attendance = Attendance(
              id: 0, // id will be set by backend
              memberId: _selectedMemberId!,
              salonId: selectedSalonId!, // type fix: int? to int
              date: dateTime,
            );
            print(
              '[attendance] ADD SUBMIT memberId: ${attendance.memberId}, salonId: ${attendance.salonId}, date: ${attendance.date.toIso8601String()}',
            );
            final result = await widget.ref
                .read(attendanceProvider.notifier)
                .addAttendance(attendance, widget.token);
            if (result == null) {
              Navigator.pop(context, true); // success
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result), backgroundColor: Colors.red),
                );
              }
            }
          },
          icon: const Icon(AppIcons.save, size: 18),
          label: Text(loc?.translate('add') ?? 'Add'),
        ),
      ],
    );
  }
}
