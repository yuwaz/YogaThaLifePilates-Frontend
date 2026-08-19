import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/reservation_provider.dart';
import '../providers/subscription_enforcement_provider.dart';
import '../api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/member.dart';
import '../models/reservation.dart';
import '../models/salon.dart';
import '../models/equipment.dart';
import 'reservation_form_dialog.dart';
import 'reservation_detail_dialog.dart';
import 'member_measurement_history_page.dart';
import 'member_measurement_dialog.dart';
import '../l10n/app_localizations.dart';
import '../providers/member_provider.dart';
import '../providers/member_types_provider.dart';
import '../theme/app_design_tokens.dart';

class MemberDetailPage extends ConsumerStatefulWidget {
  final Member member;
  final List<Salon> salons;
  final List<Equipment> equipment;
  final String token;

  const MemberDetailPage({
    Key? key,
    required this.member,
    required this.salons,
    required this.equipment,
    required this.token,
  }) : super(key: key);

  @override
  ConsumerState<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends ConsumerState<MemberDetailPage> {
  final GlobalKey _reservationsSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  bool _reservationsRequested = false;

  final Map<String, String?> _measurements = {
    'Boy': null,
    'Kilo': null,
    'Bel': null,
    'Kalca': null,
    'Gogus': null,
    'Kol': null,
    'Bacak': null,
    'Omuz': null,
    'Yag Orani': null,
  };

  String _measurementDisplayLabel(String key) {
    switch (key) {
      case 'Kalca':
        return 'Kalça';
      case 'Gogus':
      case 'gogus':
      case 'Gögüs':
        return 'Göğüs';
      case 'Gogus Olcusu':
        return 'Göğüs Ölçüsü';
      case 'Yag Orani':
        return 'Yağ Oranı';
      default:
        return key;
    }
  }

  String _formatMeasurementValue(double? value) {
    if (value == null) {
      return '-';
    }
    if (value.truncateToDouble() == value) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  Map<String, String> _measurementDisplayValues(Member member) {
    return {
      'Boy': _formatMeasurementValue(member.height),
      'Kilo': _formatMeasurementValue(member.weight),
      'Bel': _formatMeasurementValue(member.waist),
      'Kalca': _formatMeasurementValue(member.hip),
      'Gogus': _formatMeasurementValue(member.chest),
      'Kol': _formatMeasurementValue(member.arm),
      'Bacak': _formatMeasurementValue(member.leg),
      'Omuz': _formatMeasurementValue(member.shoulder),
      'Yag Orani': _formatMeasurementValue(member.bodyFatPercentage),
    };
  }

  Future<void> _fetchReservationsIfNeeded() async {
    if (_reservationsRequested) {
      return;
    }
    _reservationsRequested = true;
    await ref
        .read(reservationsProvider.notifier)
        .fetchReservations(widget.token);
  }

  void _maybeFetchReservationsIfVisible() {
    if (_reservationsRequested || !_scrollController.hasClients) {
      return;
    }

    final sectionContext = _reservationsSectionKey.currentContext;
    if (sectionContext == null) {
      return;
    }

    final renderObject = sectionContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return;
    }

    final position = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final isVisible =
        position.dy < viewportHeight && position.dy + size.height > 0;

    if (isVisible) {
      _fetchReservationsIfNeeded();
    }
  }

  Future<void> _editReservation(Reservation reservation, Member member) async {
    final auth = ref.read(authProvider);
    final role = auth.role ?? 'admin';
    final assignedSalonIds = role == 'admin' ? <int>[] : auth.assignedSalonIds;
    await showDialog(
      context: context,
      builder: (ctx) => ReservationFormDialog(
        initialReservation: reservation,
        initialDate: reservation.date,
        initialHour: reservation.hour,
        salonId: reservation.salonId,
        equipmentId: reservation.equipmentId,
        members: [member],
        token: widget.token,
        role: role,
        assignedSalonIds: assignedSalonIds,
      ),
    );
  }

  Future<void> _deleteReservation(Reservation reservation) async {
    final String? deleteScope = await showDialog<String>(
      context: context,
      builder: (ctx) => ReservationDetailDialog(reservation: reservation),
    );
    if (deleteScope == 'single' || deleteScope == 'future') {
      final selectedScope = deleteScope == 'future' ? 'future' : 'single';
      final errorMessage = await ref
          .read(reservationsProvider.notifier)
          .deleteReservation(
            reservation.id,
            widget.token,
            deleteScope: selectedScope,
          );
      if (errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> deleteAssignedLessonPackage(int assignedPackageId) async {
    final baseUrl = ApiConfig.baseUrl;
    final memberId = (memberDetail ?? widget.member).id;
    final url =
        '$baseUrl/settings/members/$memberId/assigned-lesson-packages/$assignedPackageId';
    print(
      '[MemberDetailPage] Delete tapped for assignment id: $assignedPackageId',
    );
    print('[MemberDetailPage] Delete URL: $url');
    try {
      final loc = AppLocalizations.of(context);
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );
      print(
        '[MemberDetailPage] Delete response status: ${response.statusCode}',
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        clearSubscriptionEnforcementSignal(ref.read);
        await fetchDetail();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loc?.translate('lessonPackageDeleted') ??
                    'Lesson package deleted',
              ),
            ),
          );
        }
      } else {
        reportSubscriptionEnforcementResponse(
          read: ref.read,
          response: response,
          source: 'members',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc?.translate('deleteFailed') ?? 'Delete failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('[MemberDetailPage] Delete exception: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc?.translate('deleteFailed') ?? 'Delete failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Member? memberDetail;
  DateTime? _latestMeasurementDate;

  @override
  void initState() {
    super.initState();
    fetchDetail();
    _refreshLatestMeasurementDate();
    _scrollController.addListener(_maybeFetchReservationsIfVisible);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeFetchReservationsIfVisible();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeFetchReservationsIfVisible);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshLatestMeasurementDate() async {
    try {
      final history = await ref
          .read(memberProvider.notifier)
          .fetchMemberMeasurements(
            memberId: widget.member.id,
            token: widget.token,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _latestMeasurementDate = history.isNotEmpty
            ? history.first.measuredAt
            : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _latestMeasurementDate = null;
      });
    }
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) {
      return '-';
    }
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  Future<void> _showAddMeasurementRecordDialog() async {
    final saved = await showNewMeasurementDialog(
      context: context,
      ref: ref,
      memberId: widget.member.id,
      token: widget.token,
    );

    if (saved) {
      await fetchDetail();
      await _refreshLatestMeasurementDate();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Yeni ölçüm kaydedildi')));
      }
    }
  }

  Future<void> _openMeasurementHistoryPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberMeasurementHistoryPage(
          memberId: widget.member.id,
          token: widget.token,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await fetchDetail();
    await _refreshLatestMeasurementDate();
  }

  Future<void> fetchDetail() async {
    final baseUrl = ApiConfig.baseUrl;
    final url = '$baseUrl/settings/members/${widget.member.id}';
    print('[MemberDetailPage] Fetching detail URL: $url');
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      print('[MemberDetailPage] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        clearSubscriptionEnforcementSignal(ref.read);
        try {
          final data = json.decode(response.body);
          print('[MemberDetailPage] JSON parsed successfully');
          final member = Member.fromJson(data);
          print('[MemberDetailPage] Member parsed successfully');
          final assigned = member.assignedLessonPackages;
          print(
            '[MemberDetailPage] assignedLessonPackages length: '
            '${assigned != null ? assigned.length : 0}',
          );
          setState(() {
            memberDetail = member;
          });
        } catch (e) {
          print('[MemberDetailPage] JSON parse error: $e');
          setState(() {
            memberDetail = widget.member;
          });
        }
      } else {
        reportSubscriptionEnforcementResponse(
          read: ref.read,
          response: response,
          source: 'members',
        );
        print(
          '[MemberDetailPage] Request failed with status: ${response.statusCode}',
        );
        setState(() {
          memberDetail = widget.member;
        });
      }
    } catch (e) {
      print('[MemberDetailPage] Request exception: $e');
      setState(() {
        memberDetail = widget.member;
      });
    }
  }

  String _formatPrice(double value) {
    if (value.truncateToDouble() == value) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day.$month.$year';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: AppDesignTokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppDesignTokens.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5A6C6B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? AppDesignTokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final member = memberDetail ?? widget.member;
    final memberTypesState = ref.watch(memberTypesProvider);
    final memberTypeMap = {
      for (final mt in memberTypesState.memberTypes) mt.id: mt,
    };
    final matchedMemberType = memberTypeMap[member.memberTypeId.toString()];
    final memberTypeDisplayName =
        matchedMemberType != null && matchedMemberType.name.trim().isNotEmpty
        ? matchedMemberType.name
        : '-';
    final reservationsState = ref.watch(reservationsProvider);
    final now = DateTime.now();
    final upcomingReservations =
        reservationsState.reservations
            .where((r) => r.memberId == member.id)
            .where((r) {
              final reservationDateTime = DateTime(
                r.date.year,
                r.date.month,
                r.date.day,
                r.hour,
              );
              return !reservationDateTime.isBefore(now);
            })
            .toList()
          ..sort((a, b) {
            final aDateTime = DateTime(
              a.date.year,
              a.date.month,
              a.date.day,
              a.hour,
            );
            final bDateTime = DateTime(
              b.date.year,
              b.date.month,
              b.date.day,
              b.hour,
            );
            return aDateTime.compareTo(bDateTime);
          });
    final topUpcomingReservations = upcomingReservations.take(10).toList();
    final assignedLessonPackages = memberDetail?.assignedLessonPackages;
    if (assignedLessonPackages != null) {
      print(
        '[MemberDetailPage UI] rendering assignedLessonPackages length: ${assignedLessonPackages.length}',
      );
    }
    Color memberTypeColor;
    try {
      final hex = (matchedMemberType?.color ?? '').replaceAll('#', '');
      memberTypeColor = hex.isEmpty
          ? AppDesignTokens.backgroundSecondary
          : Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      memberTypeColor = AppDesignTokens.backgroundSecondary;
    }
    final memberSalons = member.assignedSalonIds.map((id) {
      return widget.salons.firstWhere(
        (s) => s.id == id,
        orElse: () => Salon(id: id, name: 'Unknown', type: 'Unknown'),
      );
    }).toList();

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.primaryAction,
        title: Text(
          loc?.translate('memberDetails') ?? 'Member Details',
          style: AppTypography.cardTitle,
        ),
        iconTheme: const IconThemeData(
          color: AppDesignTokens.primaryActionForeground,
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          controller: _scrollController,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignTokens.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: memberTypeColor,
                    child: Text(
                      member.name.isNotEmpty ? member.name[0] : '?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: memberTypeColor.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppDesignTokens.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: memberSalons.isEmpty
                              ? [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          AppDesignTokens.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      loc?.translate('salon') ?? 'Salon',
                                      style: const TextStyle(
                                        color: AppDesignTokens.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ]
                              : memberSalons
                                    .map(
                                      (salon) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppDesignTokens.textSecondary,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          salon.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle('Üye Bilgileri'),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 380 ? 2 : 1;
                final cardWidth =
                    (constraints.maxWidth - (columns == 2 ? 12 : 0)) / columns;

                final cards = [
                  _infoCard(
                    icon: Icons.email_outlined,
                    label: loc?.translate('email') ?? 'E-posta',
                    value: member.email,
                  ),
                  _infoCard(
                    icon: Icons.phone_outlined,
                    label: loc?.translate('phone') ?? 'Telefon',
                    value: member.phone,
                  ),
                  _infoCard(
                    icon: Icons.menu_book_outlined,
                    label: 'Kalan Ders',
                    value: member.remainingLessons.toString(),
                  ),
                  _infoCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Toplam Borç',
                    value: '₺${_formatPrice(member.totalDebt)}',
                  ),
                  _infoCard(
                    icon: Icons.event_outlined,
                    label: 'Kayıt Tarihi',
                    value: _formatDate(member.createdAt),
                  ),
                  _infoCard(
                    icon: Icons.verified_user_outlined,
                    label: 'Üye Tipi',
                    value: memberTypeDisplayName,
                    valueColor: memberTypeColor,
                  ),
                ];

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards
                      .map((card) => SizedBox(width: cardWidth, child: card))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppDesignTokens.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 560;

                      final buttons = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showAddMeasurementRecordDialog,
                            style: AppButtonStyles.secondary,
                            icon: const Icon(AppIcons.create, size: 18),
                            label: const Text('Yeni Ölçüm'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openMeasurementHistoryPage,
                            style: AppButtonStyles.secondary,
                            icon: const Icon(AppIcons.history, size: 18),
                            label: const Text('Ölçüm Geçmişi'),
                          ),
                        ],
                      );

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Son Ölçüm',
                              style: AppTypography.sectionTitle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateTime(_latestMeasurementDate),
                              style: AppTypography.caption,
                            ),
                            const SizedBox(height: 10),
                            buttons,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Son Ölçüm',
                                  style: AppTypography.sectionTitle,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDateTime(_latestMeasurementDate),
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          buttons,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final measurementValues = _measurementDisplayValues(
                        member,
                      );
                      final columns = constraints.maxWidth >= 380 ? 2 : 1;
                      final itemWidth =
                          (constraints.maxWidth - (columns == 2 ? 10 : 0)) /
                          columns;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _measurements.entries.map((entry) {
                          return SizedBox(
                            width: itemWidth,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppDesignTokens.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _measurementDisplayLabel(entry.key),
                                    style: const TextStyle(
                                      color: Color(0xFF5A6C6B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    measurementValues[entry.key] ?? '-',
                                    style: const TextStyle(
                                      color: AppDesignTokens.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Atanan Ders Paketleri',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppDesignTokens.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            if (assignedLessonPackages != null &&
                assignedLessonPackages.isNotEmpty)
              ...assignedLessonPackages.map((pkg) {
                // pkg is likely Map<String, dynamic>
                final name = pkg is Map ? pkg['name']?.toString() ?? '' : '';
                final lessonCount = pkg is Map
                    ? pkg['lessonCount']?.toString() ?? ''
                    : '';
                final priceRaw = pkg is Map ? pkg['price'] : null;
                String priceStr = '';
                if (priceRaw != null) {
                  final priceNum = priceRaw is num
                      ? priceRaw
                      : num.tryParse(priceRaw.toString()) ?? 0;
                  priceStr = priceNum.truncateToDouble() == priceNum
                      ? priceNum.toStringAsFixed(0)
                      : priceNum.toStringAsFixed(2);
                }
                final assignedAtRaw = pkg is Map
                    ? pkg['assignedAt']?.toString()
                    : null;
                String formattedDate = '';
                if (assignedAtRaw != null && assignedAtRaw.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(assignedAtRaw).toLocal();
                    final day = dt.day.toString().padLeft(2, '0');
                    final month = dt.month.toString().padLeft(2, '0');
                    final year = dt.year.toString();
                    final hour = dt.hour.toString().padLeft(2, '0');
                    final minute = dt.minute.toString().padLeft(2, '0');
                    formattedDate = '$day.$month.$year $hour:$minute';
                  } catch (_) {
                    formattedDate = assignedAtRaw;
                  }
                }
                final assignedId = pkg is Map ? pkg['id'] : null;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: AppDesignTokens.surface,
                  elevation: 2,
                  shadowColor: const Color(0x17000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (lessonCount.isNotEmpty)
                              Text(
                                '${loc?.translate('lessonCount') ?? 'Lesson Count'}: $lessonCount',
                              ),
                            if (priceStr.isNotEmpty)
                              Text(
                                '${loc?.translate('price') ?? 'Price'}: ₺$priceStr',
                              ),
                            if (formattedDate.isNotEmpty)
                              Text(
                                '${loc?.translate('date') ?? 'Date'}: $formattedDate',
                              ),
                          ],
                        ),
                      ),
                      if (assignedId != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(
                              AppIcons.delete,
                              color: AppDesignTokens.destructive,
                            ),
                            tooltip: 'Sil',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    loc?.translate('delete') ?? 'Delete',
                                  ),
                                  content: Text(
                                    loc?.translate(
                                          'deleteLessonPackageConfirm',
                                        ) ??
                                        'Are you sure you want to delete this lesson package?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: Text(
                                        loc?.translate('cancel') ?? 'Cancel',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: Text(
                                        loc?.translate('delete') ?? 'Delete',
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await deleteAssignedLessonPackage(
                                  assignedId is int
                                      ? assignedId
                                      : int.tryParse(assignedId.toString()) ??
                                            -1,
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 16),
            Container(
              key: _reservationsSectionKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yaklaşan Rezervasyonlar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppDesignTokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_reservationsRequested &&
                      !reservationsState.isLoading &&
                      reservationsState.reservations.isEmpty)
                    const Text(
                      'Rezervasyonlar göründüğünde yüklenecek',
                      style: AppTypography.body,
                    )
                  else if (reservationsState.isLoading)
                    const Text(
                      'Rezervasyonlar yükleniyor...',
                      style: AppTypography.body,
                    )
                  else if (topUpcomingReservations.isEmpty)
                    const Text(
                      'Yaklaşan rezervasyon yok',
                      style: AppTypography.body,
                    )
                  else
                    ...topUpcomingReservations.map((reservation) {
                      final day = reservation.date.day.toString().padLeft(
                        2,
                        '0',
                      );
                      final month = reservation.date.month.toString().padLeft(
                        2,
                        '0',
                      );
                      final year = reservation.date.year.toString();
                      final hour = reservation.hour.toString().padLeft(2, '0');
                      final minute = reservation.minute.toString().padLeft(
                        2,
                        '0',
                      );
                      final salon = widget.salons.firstWhere(
                        (s) => s.id == reservation.salonId,
                        orElse: () => Salon(
                          id: reservation.salonId,
                          name: 'Salon ${reservation.salonId}',
                          type: 'Unknown',
                        ),
                      );
                      final equipment = widget.equipment.firstWhere(
                        (e) => e.id == reservation.equipmentId,
                        orElse: () => Equipment(
                          id: reservation.equipmentId,
                          name: 'Ekipman ${reservation.equipmentId}',
                          type: 'Unknown',
                          salonId: reservation.salonId,
                        ),
                      );
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        color: AppDesignTokens.surface,
                        elevation: 2,
                        shadowColor: const Color(0x17000000),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          title: Text(
                            '$day.$month.$year  $hour:$minute',
                            style: const TextStyle(
                              color: AppDesignTokens.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Salon: ${salon.name}',
                                style: AppTypography.body,
                              ),
                              Text(
                                'Ekipman: ${equipment.name}',
                                style: AppTypography.body,
                              ),
                              if (reservation.recurrenceGroupId != null &&
                                  reservation.recurrenceGroupId!.isNotEmpty)
                                const Text(
                                  'Tekrarlı rezervasyon',
                                  style: TextStyle(
                                    color: AppDesignTokens.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  AppIcons.edit,
                                  color: AppDesignTokens.textPrimary,
                                ),
                                tooltip: loc?.translate('edit') ?? 'Edit',
                                onPressed: () =>
                                    _editReservation(reservation, member),
                              ),
                              IconButton(
                                icon: const Icon(
                                  AppIcons.delete,
                                  color: AppDesignTokens.destructive,
                                ),
                                tooltip: loc?.translate('delete') ?? 'Delete',
                                onPressed: () =>
                                    _deleteReservation(reservation),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
