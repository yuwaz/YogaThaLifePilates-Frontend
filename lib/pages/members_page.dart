import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_design_tokens.dart';
import '../models/member.dart';
import '../models/salon.dart';
import '../providers/member_provider.dart';
import '../providers/instructors_provider.dart';
import '../providers/salons_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/member_types_provider.dart';
import '../providers/lesson_packages_provider.dart';
import 'member_detail_page.dart';
import 'member_edit_dialog.dart';

class MembersPage extends ConsumerStatefulWidget {
  final String token;
  final String role;
  final List<int> assignedSalonIds;

  const MembersPage({
    Key? key,
    required this.token,
    required this.role,
    required this.assignedSalonIds,
  }) : super(key: key);

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  // Removed unused: _isDeleting, _recentlyDeleted, _recentlyDeletedIndex
  List<int> _selectedSalonIds = [];
  String? _selectedMemberTypeId;
  String? _selectedInstructorId;
  bool _showInactive = false;
  String _memberSearchQuery = '';
  String _selectedSort = 'created_desc';
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  List<Member> _filteredMembers = const [];
  List<Member>? _lastMembersSource;
  List<MemberType>? _lastMemberTypesSource;
  bool _needsMemberRecompute = true;

  Future<void> _refreshMembers() async {
    if (_showInactive) {
      await ref.read(memberProvider.notifier).fetchAllMembers(widget.token);
    } else {
      await ref.read(memberProvider.notifier).fetchMembers(widget.token);
    }
  }

  void _markMembersDirty() {
    _needsMemberRecompute = true;
  }

  void _recomputeMembers(
    List<Member> members,
    Map<String, MemberType> memberTypeMap,
    bool isAdmin,
    List<int> allowedSalonIds,
  ) {
    final filtered = members.where((m) {
      if (_showInactive) {
        if (m.isActive) return false;
      } else {
        if (!m.isActive) return false;
      }
      if (_selectedSalonIds.isNotEmpty &&
          !m.assignedSalonIds.any((id) => _selectedSalonIds.contains(id))) {
        return false;
      }
      if (_selectedMemberTypeId != null &&
          m.memberTypeId.toString() != _selectedMemberTypeId) {
        return false;
      }
      if (_selectedInstructorId != null &&
          m.assignedInstructorId?.toString() != _selectedInstructorId) {
        return false;
      }
      if (!isAdmin &&
          !m.assignedSalonIds.any((id) => allowedSalonIds.contains(id))) {
        return false;
      }
      if (_memberSearchQuery.isNotEmpty) {
        final query = _memberSearchQuery;
        final name = m.name.toLowerCase();
        final phone = m.phone.toLowerCase();
        final email = m.email.toLowerCase();
        if (!name.contains(query) &&
            !phone.contains(query) &&
            !email.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_selectedSort) {
        case 'remaining_asc':
          final aCardBased = _isCardBasedMember(a, memberTypeMap);
          final bCardBased = _isCardBasedMember(b, memberTypeMap);
          if (aCardBased != bCardBased) {
            return aCardBased ? 1 : -1;
          }
          final remainingCompare = a.remainingLessons.compareTo(
            b.remainingLessons,
          );
          if (remainingCompare != 0) return remainingCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'remaining_desc':
          final aCardBased = _isCardBasedMember(a, memberTypeMap);
          final bCardBased = _isCardBasedMember(b, memberTypeMap);
          if (aCardBased != bCardBased) {
            return aCardBased ? 1 : -1;
          }
          final remainingCompare = b.remainingLessons.compareTo(
            a.remainingLessons,
          );
          if (remainingCompare != 0) return remainingCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'created_asc':
          final aCreated = _memberCreatedAt(a);
          final bCreated = _memberCreatedAt(b);
          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;
          return aCreated.compareTo(bCreated);
        case 'created_desc':
        default:
          final aCreated = _memberCreatedAt(a);
          final bCreated = _memberCreatedAt(b);
          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;
          return bCreated.compareTo(aCreated);
      }
    });

    _filteredMembers = filtered;
    _needsMemberRecompute = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salons = ref.read(salonsProvider).salons;
      if (!mounted) return;
      setState(() {
        if (widget.role == 'admin') {
          _selectedSalonIds = salons.map((s) => s.id).toList();
        } else {
          _selectedSalonIds = List<int>.from(widget.assignedSalonIds);
        }
      });
      // Fetch on first page load only when provider has no data yet.
      if (ref.read(memberProvider).members.isEmpty) {
        ref.read(memberProvider.notifier).fetchMembers(widget.token);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _safeText(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  Color _parseMemberTypeColor(dynamic hex) {
    try {
      final raw = _safeText(hex).replaceAll('#', '');
      final safeHex = raw.isEmpty ? '888888' : raw;
      return Color(int.parse('FF$safeHex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  bool _isCardBasedMember(
    Member member,
    Map<String, MemberType> memberTypeMap,
  ) {
    final memberType = memberTypeMap[member.memberTypeId.toString()];
    return memberType?.isCardBased == true;
  }

  DateTime? _memberCreatedAt(dynamic member) {
    try {
      final value = member.createdAt;
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    } catch (_) {
      return null;
    }
  }

  String _sortLabel() {
    switch (_selectedSort) {
      case 'created_asc':
        return 'Sırala: Eski → Yeni';
      case 'remaining_asc':
        return 'Sırala: Ders Artan';
      case 'remaining_desc':
        return 'Sırala: Ders Azalan';
      case 'created_desc':
      default:
        return 'Sırala: Yeni → Eski';
    }
  }

  List<int> _defaultSalonIds(List<Salon> salons) {
    if (widget.role == 'admin') {
      return salons.map((s) => s.id).toList();
    }
    return salons
        .where((s) => widget.assignedSalonIds.contains(s.id))
        .map((s) => s.id)
        .toList();
  }

  bool _hasCustomSalonFilter(List<Salon> salons) {
    final defaultSalonIds = _defaultSalonIds(salons).toSet();
    final selectedSalonIds = _selectedSalonIds.toSet();
    return selectedSalonIds.length != defaultSalonIds.length ||
        !selectedSalonIds.containsAll(defaultSalonIds);
  }

  bool _hasActiveFilters(List<Salon> salons) {
    return _hasCustomSalonFilter(salons) ||
        _selectedMemberTypeId != null ||
        _selectedInstructorId != null;
  }

  String _filterButtonLabel(List<Salon> salons) {
    var activeFilterCount = 0;
    if (_hasCustomSalonFilter(salons)) activeFilterCount++;
    if (_selectedMemberTypeId != null) activeFilterCount++;
    if (_selectedInstructorId != null) activeFilterCount++;
    if (activeFilterCount == 0) return 'Filtrele';
    return 'Filtrele ($activeFilterCount)';
  }

  ButtonStyle _topActionButtonStyle({required bool isActive}) {
    return (isActive ? AppButtonStyles.primary : AppButtonStyles.secondary)
        .copyWith(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14),
          ),
        );
  }

  Future<void> _showFilterDialog(
    BuildContext context,
    List<Salon> salons,
    MemberTypesState memberTypesState,
    InstructorsState instructorsState,
  ) async {
    final defaultSalonIds = _defaultSalonIds(salons);
    int? tempSelectedSalonId;
    if (_selectedSalonIds.length == defaultSalonIds.length &&
        _selectedSalonIds.toSet().containsAll(defaultSalonIds)) {
      tempSelectedSalonId = null;
    } else if (_selectedSalonIds.isNotEmpty) {
      tempSelectedSalonId = _selectedSalonIds.first;
    }
    var tempSelectedMemberTypeId = _selectedMemberTypeId;
    var tempSelectedInstructorId = _selectedInstructorId;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Filtrele'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int?>(
                        key: ValueKey(
                          tempSelectedSalonId ?? 'dialog_all_salons',
                        ),
                        initialValue: tempSelectedSalonId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Tüm Salonlar'),
                          ),
                          ...salons.map(
                            (salon) => DropdownMenuItem<int?>(
                              value: salon.id,
                              child: Text(
                                salon.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            tempSelectedSalonId = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Salon',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: AppDesignTokens.surface,
                        ),
                        dropdownColor: AppDesignTokens.surface,
                        iconEnabledColor: AppDesignTokens.textPrimary,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String?>(
                        key: ValueKey(
                          tempSelectedMemberTypeId ?? 'dialog_all_member_types',
                        ),
                        initialValue: tempSelectedMemberTypeId,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tüm Üye Tipleri'),
                          ),
                          ...memberTypesState.memberTypes.map(
                            (memberType) => DropdownMenuItem<String?>(
                              value: memberType.id,
                              child: Text(
                                memberType.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            tempSelectedMemberTypeId = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Üye Tipi',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: AppDesignTokens.surface,
                        ),
                        dropdownColor: AppDesignTokens.surface,
                        iconEnabledColor: AppDesignTokens.textPrimary,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String?>(
                        key: ValueKey(
                          tempSelectedInstructorId ?? 'dialog_all_instructors',
                        ),
                        initialValue: tempSelectedInstructorId,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tüm Eğitmenler'),
                          ),
                          ...instructorsState.instructors.map(
                            (instructor) => DropdownMenuItem<String?>(
                              value: instructor.id,
                              child: Text(
                                instructor.username,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            tempSelectedInstructorId = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Eğitmen',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: AppDesignTokens.surface,
                        ),
                        dropdownColor: AppDesignTokens.surface,
                        iconEnabledColor: AppDesignTokens.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      tempSelectedSalonId = null;
                      tempSelectedMemberTypeId = null;
                      tempSelectedInstructorId = null;
                    });
                  },
                  child: const Text('Temizle'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  style: AppButtonStyles.primary,
                  onPressed: () {
                    setState(() {
                      _selectedSalonIds = tempSelectedSalonId == null
                          ? [...defaultSalonIds]
                          : [tempSelectedSalonId!];
                      _selectedMemberTypeId = tempSelectedMemberTypeId;
                      _selectedInstructorId = tempSelectedInstructorId;
                      _markMembersDirty();
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Uygula'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Removed unused: _memberTypeLabel

  @override
  Widget build(BuildContext context) {
    final memberState = ref.watch(memberProvider);
    final instructorsState = ref.watch(instructorsProvider);
    final salons = ref.watch(salonsProvider).salons;
    final equipment = ref.watch(equipmentProvider).equipmentList;
    final memberTypesState = ref.watch(memberTypesProvider);
    final memberTypeMap = {
      for (final mt in memberTypesState.memberTypes) mt.id: mt,
    };
    final isAdmin = widget.role == 'admin';
    final availableSalons = isAdmin
        ? salons
        : salons.where((s) => widget.assignedSalonIds.contains(s.id)).toList();
    final allowedSalonIds = isAdmin
        ? salons.map((s) => s.id).toList()
        : widget.assignedSalonIds;
    final l10n = AppLocalizations.of(context);

    if (!identical(_lastMembersSource, memberState.members)) {
      _lastMembersSource = memberState.members;
      _markMembersDirty();
    }
    if (!identical(_lastMemberTypesSource, memberTypesState.memberTypes)) {
      _lastMemberTypesSource = memberTypesState.memberTypes;
      _markMembersDirty();
    }
    if (_needsMemberRecompute) {
      _recomputeMembers(
        memberState.members,
        memberTypeMap,
        isAdmin,
        allowedSalonIds,
      );
    }

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
            l10n?.translate('members') ?? 'Members',
            style: AppTypography.sectionTitle,
            textAlign: TextAlign.left,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() {
                _showInactive = !_showInactive;
                _markMembersDirty();
              });
              if (_showInactive) {
                await ref
                    .read(memberProvider.notifier)
                    .fetchAllMembers(widget.token);
              } else {
                await ref
                    .read(memberProvider.notifier)
                    .fetchMembers(widget.token);
              }
            },
            child: Text(
              _showInactive ? 'Aktif Üyeler' : 'Pasif Üyeler',
              style: AppTypography.button.copyWith(
                color: AppDesignTokens.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshMembers();
            },
          ),
          const Padding(padding: EdgeInsets.only(right: 8)),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Üye ara',
                  prefixIcon: const Icon(AppIcons.search),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: AppDesignTokens.surface,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(AppIcons.close),
                          onPressed: () {
                            _searchDebounce?.cancel();
                            _searchController.clear();
                            setState(() {
                              _memberSearchQuery = '';
                              _markMembersDirty();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 200),
                    () {
                      if (!mounted) return;
                      setState(() {
                        _memberSearchQuery = value.trim().toLowerCase();
                        _markMembersDirty();
                      });
                    },
                  );
                  setState(() {});
                },
              ),
            ),
            if (availableSalons.isNotEmpty ||
                memberTypesState.memberTypes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          AppIcons.filter,
                          color: _hasActiveFilters(availableSalons)
                              ? AppDesignTokens.primaryActionForeground
                              : AppDesignTokens.textPrimary,
                        ),
                        label: Text(
                          _filterButtonLabel(availableSalons),
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.button.copyWith(
                            color: _hasActiveFilters(availableSalons)
                                ? AppDesignTokens.primaryActionForeground
                                : AppDesignTokens.textPrimary,
                          ),
                        ),
                        style: _topActionButtonStyle(
                          isActive: _hasActiveFilters(availableSalons),
                        ),
                        onPressed: () {
                          _showFilterDialog(
                            context,
                            availableSalons,
                            memberTypesState,
                            instructorsState,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PopupMenuButton<String>(
                        onSelected: (selected) {
                          setState(() {
                            _selectedSort = selected;
                            _markMembersDirty();
                          });
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'created_desc',
                            child: Text(
                              'Kayıt Tarihi Yeni → Eski',
                              style: AppTypography.body,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'created_asc',
                            child: Text(
                              'Kayıt Tarihi Eski → Yeni',
                              style: AppTypography.body,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remaining_asc',
                            child: Text(
                              'Kalan Ders Artan',
                              style: AppTypography.body,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remaining_desc',
                            child: Text(
                              'Kalan Ders Azalan',
                              style: AppTypography.body,
                            ),
                          ),
                        ],
                        child: IgnorePointer(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.sort,
                              color: AppDesignTokens.textSecondary,
                              size: 24,
                            ),
                            label: Text(
                              _sortLabel(),
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.button.copyWith(
                                color: AppDesignTokens.textSecondary,
                              ),
                            ),
                            style: _topActionButtonStyle(isActive: false),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (memberState.status == MemberStatus.loading &&
                      memberState.members.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppDesignTokens.primaryAction,
                      ),
                    );
                  }
                  if (memberTypesState.isLoading &&
                      memberTypesState.memberTypes.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppDesignTokens.primaryAction,
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _refreshMembers,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        final memberType =
                            memberTypeMap[member.memberTypeId.toString()];
                        final memberTypeColor =
                            memberType != null && memberType.color.isNotEmpty
                            ? _parseMemberTypeColor(memberType.color)
                            : Colors.grey;
                        final memberTypeLabel =
                            memberType != null && memberType.name.isNotEmpty
                            ? memberType.name
                            : (l10n?.translate('unknown') ?? 'Unknown');
                        final isCardBasedMember =
                            memberType?.isCardBased == true;
                        final memberName = _safeText(member.name);
                        // Removed unused: memberPhone, memberEmail

                        return Card(
                          color: AppDesignTokens.surface,
                          margin: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 2,
                          ),
                          elevation: 2,
                          child: ListTile(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MemberDetailPage(
                                    member: member,
                                    salons: salons,
                                    equipment: equipment,
                                    token: widget.token,
                                  ),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: memberTypeColor,
                              child: Text(
                                memberName.isNotEmpty ? memberName[0] : '?',
                                style: TextStyle(
                                  color:
                                      memberTypeColor.computeLuminance() > 0.5
                                      ? AppDesignTokens.textPrimary
                                      : AppDesignTokens.primaryActionForeground,
                                ),
                              ),
                            ),
                            title: Text(memberName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (l10n?.translate('type') ?? 'Type') +
                                      ': $memberTypeLabel',
                                ),
                                if (!isCardBasedMember)
                                  Text(
                                    (l10n?.translate('remainingLessons') ??
                                            'Remaining lessons') +
                                        ': ${member.remainingLessons}',
                                    style: AppTypography.body.copyWith(
                                      color: member.remainingLessons <= 3
                                          ? AppDesignTokens.error
                                          : AppDesignTokens.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: (_showInactive && isAdmin)
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.restore,
                                      color: AppDesignTokens.textPrimary,
                                    ),
                                    tooltip:
                                        l10n?.translate('reactivate') ??
                                        'Reactivate Member',
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) {
                                          return AlertDialog(
                                            title: Text('Üyeyi Aktifleştir'),
                                            content: Text(
                                              'Bu üyeyi tekrar aktifleştirmek istediğinize emin misiniz?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  dialogContext,
                                                ).pop(false),
                                                child: Text('İptal'),
                                              ),
                                              ElevatedButton(
                                                style: AppButtonStyles.primary,
                                                onPressed: () => Navigator.of(
                                                  dialogContext,
                                                ).pop(true),
                                                child: Text('Aktifleştir'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (confirmed == true) {
                                        final restoreResult = await ref
                                            .read(memberProvider.notifier)
                                            .restoreMember(
                                              member.id,
                                              widget.token,
                                            );
                                        if (restoreResult == null) {
                                          await ref
                                              .read(memberProvider.notifier)
                                              .fetchAllMembers(widget.token);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n?.translate(
                                                      'memberReactivatedSuccessfully',
                                                    ) ??
                                                    'Member reactivated successfully',
                                              ),
                                              backgroundColor:
                                                  AppDesignTokens.success,
                                            ),
                                          );
                                        } else {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(restoreResult),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const FaIcon(
                                          FontAwesomeIcons.whatsapp,
                                          color: Colors.green,
                                        ),
                                        tooltip: 'WhatsApp',
                                        onPressed: () async {
                                          final phone = member.phone
                                              .replaceAll('+', '')
                                              .replaceAll(' ', '');
                                          if (phone.isEmpty) return;

                                          final url = Uri.parse(
                                            'https://wa.me/$phone',
                                          );

                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(
                                              url,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          }
                                        },
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            final result = await showDialog<bool>(
                                              context: context,
                                              builder: (dialogContext) {
                                                return MemberEditDialog(
                                                  token: widget.token,
                                                  member: member,
                                                  onSave:
                                                      (
                                                        name,
                                                        phone,
                                                        email,
                                                        memberTypeId,
                                                        assignedSalonIds,
                                                        assignedEquipmentIds,
                                                        remainingLessons,
                                                        assignedInstructorId,
                                                      ) async {
                                                        final updatedMember = Member(
                                                          id: member.id,
                                                          name: name,
                                                          phone: phone,
                                                          email: email,
                                                          memberTypeId:
                                                              memberTypeId,
                                                          memberTypeName: member
                                                              .memberTypeName,
                                                          memberTypeColor: member
                                                              .memberTypeColor,
                                                          assignedSalonIds:
                                                              assignedSalonIds,
                                                          assignedEquipmentIds:
                                                              assignedEquipmentIds,
                                                          remainingLessons:
                                                              remainingLessons,
                                                          totalDebt:
                                                              member.totalDebt,
                                                          assignedInstructorId:
                                                              assignedInstructorId,
                                                        );
                                                        final updateResult =
                                                            await ref
                                                                .read(
                                                                  memberProvider
                                                                      .notifier,
                                                                )
                                                                .updateMember(
                                                                  updatedMember,
                                                                  widget.token,
                                                                );
                                                        if (updateResult ==
                                                            null) {
                                                          return null;
                                                        }
                                                        if (!dialogContext
                                                            .mounted)
                                                          return updateResult;
                                                        ScaffoldMessenger.of(
                                                          dialogContext,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              updateResult,
                                                            ),
                                                            backgroundColor:
                                                                Colors.red,
                                                          ),
                                                        );
                                                        return updateResult;
                                                      },
                                                );
                                              },
                                            );
                                            if (result == true) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l10n?.translate(
                                                          'memberUpdatedSuccessfully',
                                                        ) ??
                                                        'Member updated successfully',
                                                  ),
                                                  backgroundColor:
                                                      AppDesignTokens.success,
                                                ),
                                              );
                                            }
                                          }
                                          if (value == 'assign_package') {
                                            await ref
                                                .read(
                                                  lessonPackagesProvider
                                                      .notifier,
                                                )
                                                .fetchLessonPackages();
                                            String? selectedPackageId;
                                            String? errorText;
                                            String discountType = 'none';
                                            final TextEditingController
                                            discountValueController =
                                                TextEditingController();
                                            double finalPrice = 0;
                                            int originalPrice = 0;
                                            await showDialog(
                                              context: context,
                                              builder: (dialogContext) {
                                                return StatefulBuilder(
                                                  builder: (context, setState) {
                                                    return Consumer(
                                                      builder: (context, ref, _) {
                                                        final lessonPackagesState =
                                                            ref.watch(
                                                              lessonPackagesProvider,
                                                            );
                                                        final packages =
                                                            lessonPackagesState
                                                                .lessonPackages;
                                                        final isLoading =
                                                            lessonPackagesState
                                                                .isLoading &&
                                                            packages.isEmpty;
                                                        final selectedPkg =
                                                            packages.firstWhere(
                                                              (p) =>
                                                                  (p as dynamic)
                                                                      .id ==
                                                                  selectedPackageId,
                                                              orElse: () =>
                                                                  packages[0],
                                                            );
                                                        originalPrice =
                                                            (selectedPkg
                                                                    as dynamic)
                                                                .price;
                                                        double discountValue =
                                                            double.tryParse(
                                                              discountValueController
                                                                  .text,
                                                            ) ??
                                                            0;
                                                        if (discountType ==
                                                            'none') {
                                                          finalPrice =
                                                              originalPrice
                                                                  .toDouble();
                                                        } else if (discountType ==
                                                            'amount') {
                                                          finalPrice =
                                                              (originalPrice -
                                                                      discountValue)
                                                                  .clamp(
                                                                    0,
                                                                    originalPrice,
                                                                  )
                                                                  .toDouble();
                                                        } else if (discountType ==
                                                            'percent') {
                                                          finalPrice =
                                                              (originalPrice -
                                                                      (originalPrice *
                                                                          discountValue /
                                                                          100))
                                                                  .clamp(
                                                                    0,
                                                                    originalPrice,
                                                                  )
                                                                  .toDouble();
                                                        }
                                                        return AlertDialog(
                                                          title: Text(
                                                            l10n?.translate(
                                                                  'assignLessonPackage',
                                                                ) ??
                                                                'Ders Paketi Ata',
                                                          ),
                                                          content: isLoading
                                                              ? const SizedBox(
                                                                  height: 80,
                                                                  child: Center(
                                                                    child:
                                                                        CircularProgressIndicator(),
                                                                  ),
                                                                )
                                                              : Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    DropdownButtonFormField<
                                                                      String
                                                                    >(
                                                                      value:
                                                                          selectedPackageId,
                                                                      items: packages
                                                                          .map(
                                                                            (
                                                                              pkg,
                                                                            ) => DropdownMenuItem(
                                                                              value: pkg.id,
                                                                              child: Text(
                                                                                '${pkg.name} (${pkg.lessonCount} ders, ₺${pkg.price})',
                                                                              ),
                                                                            ),
                                                                          )
                                                                          .toList(),
                                                                      onChanged: (val) {
                                                                        setState(() {
                                                                          selectedPackageId =
                                                                              val;
                                                                          errorText =
                                                                              null;
                                                                          discountType =
                                                                              'none';
                                                                          discountValueController.text =
                                                                              '';
                                                                        });
                                                                      },
                                                                      decoration: InputDecoration(
                                                                        labelText:
                                                                            l10n?.translate(
                                                                              'selectPackage',
                                                                            ) ??
                                                                            'Select Package',
                                                                      ),
                                                                    ),
                                                                    if (selectedPackageId !=
                                                                        null) ...[
                                                                      const SizedBox(
                                                                        height:
                                                                            12,
                                                                      ),
                                                                      Text(
                                                                        'Standart Fiyat: ₺${(selectedPkg as dynamic).price.toStringAsFixed(2)}',
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            8,
                                                                      ),
                                                                      DropdownButtonFormField<
                                                                        String
                                                                      >(
                                                                        value:
                                                                            discountType,
                                                                        items: [
                                                                          DropdownMenuItem(
                                                                            value:
                                                                                'none',
                                                                            child: Text(
                                                                              'İndirim Yok',
                                                                            ),
                                                                          ),
                                                                          DropdownMenuItem(
                                                                            value:
                                                                                'amount',
                                                                            child: Text(
                                                                              'Tutar (₺)',
                                                                            ),
                                                                          ),
                                                                          DropdownMenuItem(
                                                                            value:
                                                                                'percent',
                                                                            child: Text(
                                                                              'Yüzde (%)',
                                                                            ),
                                                                          ),
                                                                        ],
                                                                        onChanged: (val) {
                                                                          setState(() {
                                                                            discountType =
                                                                                val ??
                                                                                'none';
                                                                            discountValueController.text =
                                                                                '';
                                                                          });
                                                                        },
                                                                        decoration: const InputDecoration(
                                                                          labelText:
                                                                              'İndirim Türü',
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            8,
                                                                      ),
                                                                      TextField(
                                                                        controller:
                                                                            discountValueController,
                                                                        enabled:
                                                                            discountType !=
                                                                            'none',
                                                                        keyboardType: const TextInputType.numberWithOptions(
                                                                          decimal:
                                                                              true,
                                                                        ),
                                                                        decoration: InputDecoration(
                                                                          labelText:
                                                                              'İndirim Tutarı',
                                                                          prefixText:
                                                                              discountType ==
                                                                                  'amount'
                                                                              ? '₺'
                                                                              : discountType ==
                                                                                    'percent'
                                                                              ? '%'
                                                                              : null,
                                                                        ),
                                                                        onChanged:
                                                                            (
                                                                              _,
                                                                            ) => setState(
                                                                              () {},
                                                                            ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            8,
                                                                      ),
                                                                      Text(
                                                                        'Son Fiyat: ₺${finalPrice.toStringAsFixed(2)}',
                                                                        style: AppTypography
                                                                            .bodyStrong,
                                                                      ),
                                                                    ],
                                                                    if (errorText !=
                                                                        null)
                                                                      Padding(
                                                                        padding: const EdgeInsets.only(
                                                                          top:
                                                                              8,
                                                                        ),
                                                                        child: Text(
                                                                          errorText!,
                                                                          style: AppTypography.body.copyWith(
                                                                            color:
                                                                                AppDesignTokens.error,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    dialogContext,
                                                                  ).pop(),
                                                              child: Text(
                                                                l10n?.translate(
                                                                      'cancel',
                                                                    ) ??
                                                                    'Cancel',
                                                              ),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () async {
                                                                if (selectedPackageId ==
                                                                    null) {
                                                                  setState(
                                                                    () => errorText =
                                                                        l10n?.translate(
                                                                          'pleaseSelectPackage',
                                                                        ) ??
                                                                        'Please select a package',
                                                                  );
                                                                  return;
                                                                }
                                                                final pkg = packages.firstWhere(
                                                                  (p) =>
                                                                      (p as dynamic)
                                                                          .id ==
                                                                      selectedPackageId,
                                                                );
                                                                double
                                                                discountValue =
                                                                    double.tryParse(
                                                                      discountValueController
                                                                          .text,
                                                                    ) ??
                                                                    0;
                                                                if (discountType ==
                                                                        'amount' &&
                                                                    discountValue >
                                                                        (pkg as dynamic)
                                                                            .price) {
                                                                  setState(
                                                                    () => errorText =
                                                                        'Discount cannot exceed price',
                                                                  );
                                                                  return;
                                                                }
                                                                if (discountType ==
                                                                        'percent' &&
                                                                    (discountValue <
                                                                            0 ||
                                                                        discountValue >
                                                                            100)) {
                                                                  setState(
                                                                    () => errorText =
                                                                        'Percent must be 0-100',
                                                                  );
                                                                  return;
                                                                }
                                                                if (finalPrice <
                                                                    0) {
                                                                  setState(
                                                                    () => errorText =
                                                                        'Final price cannot be negative',
                                                                  );
                                                                  return;
                                                                }
                                                                final error = await ref
                                                                    .read(
                                                                      memberProvider
                                                                          .notifier,
                                                                    )
                                                                    .assignLessonPackage(
                                                                      memberId:
                                                                          member
                                                                              .id,
                                                                      lessonPackageId: int.parse(
                                                                        (pkg
                                                                                as dynamic)
                                                                            .id,
                                                                      ),
                                                                      token: widget
                                                                          .token,
                                                                      originalPrice:
                                                                          (pkg
                                                                                  as dynamic)
                                                                              .price,
                                                                      discountType:
                                                                          discountType,
                                                                      discountValue:
                                                                          discountValue,
                                                                      finalPrice:
                                                                          finalPrice,
                                                                    );
                                                                if (error ==
                                                                    null) {
                                                                  await ref
                                                                      .read(
                                                                        memberProvider
                                                                            .notifier,
                                                                      )
                                                                      .fetchMembers(
                                                                        widget
                                                                            .token,
                                                                      );
                                                                  if (mounted) {
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(
                                                                      SnackBar(
                                                                        content: Text(
                                                                          l10n?.translate(
                                                                                'packageAssigned',
                                                                              ) ??
                                                                              'Lesson package assigned!',
                                                                        ),
                                                                        backgroundColor:
                                                                            AppDesignTokens.success,
                                                                      ),
                                                                    );
                                                                  }
                                                                  Navigator.of(
                                                                    dialogContext,
                                                                  ).pop();
                                                                } else {
                                                                  setState(
                                                                    () => errorText =
                                                                        error,
                                                                  );
                                                                }
                                                              },
                                                              child: const Text(
                                                                'Kaydet',
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          }
                                          if (value == 'deactivate') {
                                            if (member.totalDebt > 0) {
                                              await showDialog<void>(
                                                context: context,
                                                builder: (dialogContext) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                      'Üye Pasifleştirilemez',
                                                    ),
                                                    content: const Text(
                                                      'Bu üyenin borcu var. Lütfen önce borcu kapatın.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop(),
                                                        child: const Text(
                                                          'Tamam',
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                              return;
                                            }
                                            if (member.remainingLessons > 0) {
                                              final confirmReset =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (dialogContext) {
                                                      return AlertDialog(
                                                        title: const Text(
                                                          'Kalan Dersler Sıfırlanacak',
                                                        ),
                                                        content: const Text(
                                                          'Bu üyenin kalan dersi var. Pasifleştirirseniz kalan dersler sıfırlanacak. Emin misiniz?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  dialogContext,
                                                                ).pop(false),
                                                            child: const Text(
                                                              'İptal',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            style:
                                                                AppButtonStyles
                                                                    .destructive,
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  dialogContext,
                                                                ).pop(true),
                                                            child: const Text(
                                                              'Onayla',
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                              if (confirmReset == true) {
                                                final deleteResult = await ref
                                                    .read(
                                                      memberProvider.notifier,
                                                    )
                                                    .deleteMember(
                                                      member.id,
                                                      widget.token,
                                                      confirmResetLessons: true,
                                                    );
                                                if (deleteResult == null) {
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        l10n?.translate(
                                                              'memberDeactivatedSuccessfully',
                                                            ) ??
                                                            'Member deactivated successfully',
                                                      ),
                                                      backgroundColor:
                                                          AppDesignTokens
                                                              .success,
                                                    ),
                                                  );
                                                } else {
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        deleteResult,
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                              return;
                                            }
                                            // Normal deactivate confirmation
                                            final confirmed =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (dialogContext) {
                                                    return AlertDialog(
                                                      title: Text(
                                                        'Üyeyi Pasifleştir',
                                                      ),
                                                      content: Text(
                                                        'Bu üyeyi pasifleştirmek istediğinize emin misiniz?',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(false),
                                                          child: Text(
                                                            l10n?.translate(
                                                                  'cancel',
                                                                ) ??
                                                                'Cancel',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          style: AppButtonStyles
                                                              .destructive,
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(true),
                                                          child: Text(
                                                            'Pasifleştir',
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                            if (confirmed == true) {
                                              final deleteResult = await ref
                                                  .read(memberProvider.notifier)
                                                  .deleteMember(
                                                    member.id,
                                                    widget.token,
                                                  );
                                              if (deleteResult == null) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      l10n?.translate(
                                                            'memberDeactivatedSuccessfully',
                                                          ) ??
                                                          'Member deactivated successfully',
                                                    ),
                                                    backgroundColor:
                                                        AppDesignTokens.success,
                                                  ),
                                                );
                                              } else {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(deleteResult),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  AppIcons.edit,
                                                  color: AppDesignTokens
                                                      .textSecondary,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Düzenle',
                                                  style: AppTypography.body,
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'assign_package',
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.inventory_2_outlined,
                                                  color: AppDesignTokens
                                                      .textSecondary,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Ders Paketi Ata',
                                                  style: AppTypography.body,
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'deactivate',
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  AppIcons.delete,
                                                  color: AppDesignTokens
                                                      .destructive,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Pasifleştir',
                                                  style: AppTypography.body,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppDesignTokens.primaryAction,
        child: const Icon(
          AppIcons.create,
          color: AppDesignTokens.primaryActionForeground,
        ),
        onPressed: () async {
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return MemberEditDialog(
                token: widget.token,
                onSave:
                    (
                      name,
                      phone,
                      email,
                      memberTypeId,
                      assignedSalonIds,
                      assignedEquipmentIds,
                      remainingLessons,
                      assignedInstructorId,
                    ) async {
                      final member = Member(
                        id: 0,
                        name: name,
                        phone: phone,
                        email: email,
                        memberTypeId: memberTypeId,
                        memberTypeName: '',
                        memberTypeColor: '#171717',
                        assignedSalonIds: assignedSalonIds,
                        assignedEquipmentIds: assignedEquipmentIds,
                        remainingLessons: remainingLessons,
                        totalDebt: 0.0,
                        assignedInstructorId: assignedInstructorId,
                      );
                      final addResult = await ref
                          .read(memberProvider.notifier)
                          .addMember(member, widget.token);
                      if (addResult == null) {
                        if (!dialogContext.mounted) return null;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n?.translate('memberAddedSuccessfully') ??
                                  'Member added successfully',
                            ),
                            backgroundColor: AppDesignTokens.success,
                          ),
                        );
                        return null;
                      }
                      if (!dialogContext.mounted) return addResult;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(addResult),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return addResult;
                    },
              );
            },
          );
        },
      ),
    );
  }
}
