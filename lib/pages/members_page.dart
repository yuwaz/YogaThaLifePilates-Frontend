import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../models/equipment.dart';
import '../models/salon.dart';
import '../providers/member_provider.dart';
import '../widgets/multi_select_dialog.dart';
import '../providers/salons_provider.dart';
import 'member_edit_dialog.dart';
import 'member_detail_page.dart';
import '../providers/equipment_provider.dart';

import '../l10n/app_localizations.dart';

class MembersPage extends ConsumerStatefulWidget {
  final String token;
  final String role; // 'admin' or 'instructor'
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
  bool _isDeleting = false;
  Member? _recentlyDeleted;
  int? _recentlyDeletedIndex;
  List<int> _selectedSalonIds = [];
  List<int> _selectedEquipmentIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salons = ref.read(salonsProvider).salons;
      setState(() {
        if (widget.role == 'admin') {
          _selectedSalonIds = salons.map((s) => s.id).toList();
        } else {
          _selectedSalonIds = widget.assignedSalonIds;
        }
        _selectedEquipmentIds = [];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final memberState = ref.watch(memberProvider);
    final salons = ref.watch(salonsProvider).salons;
    final equipmentState = ref.watch(equipmentProvider);
    final equipment = equipmentState.equipmentList;
    final isAdmin = widget.role == 'admin';
    final assignedSalonIds = isAdmin
        ? salons.map((s) => s.id).toList()
        : widget.assignedSalonIds;

    // Filtering logic
    final filteredMembers = memberState.members.where((m) {
      if (_selectedSalonIds.isNotEmpty &&
          !m.assignedSalonIds.any((id) => _selectedSalonIds.contains(id))) {
        return false;
      }
      if (_selectedEquipmentIds.isNotEmpty) {
        final eqIds = m.assignedEquipmentIds ?? [];
        if (!eqIds.any((id) => _selectedEquipmentIds.contains(id))) {
          return false;
        }
      }
      if (!isAdmin &&
          !m.assignedSalonIds.any((id) => assignedSalonIds.contains(id))) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFf6f6d7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF116478),
        title: const Text('Members', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () =>
                ref.read(memberProvider.notifier).fetchMembers(widget.token),
          ),
          const Padding(padding: EdgeInsets.only(right: 8.0)),
        ],
      ),
      body: Column(
        children: [
          // Salon filter
          // Equipment filter
          if (equipment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.filter_alt, color: Color(0xFF116478)),
                label: Text(
                  _selectedEquipmentIds.isEmpty
                      ? (AppLocalizations.of(
                              context,
                            )?.translate('filterByEquipment') ??
                            'Filter by Equipment')
                      : (AppLocalizations.of(context)?.translate('equipment') ??
                                'Equipment') +
                            ': ' +
                            _selectedEquipmentIds
                                .map(
                                  (id) => equipment
                                      .firstWhere(
                                        (e) => e.id == id,
                                        orElse: () => Equipment(
                                          id: -1,
                                          name: 'Unknown',
                                          type: '',
                                          salonId: -1,
                                        ),
                                      )
                                      .name,
                                )
                                .join(', '),
                  style: const TextStyle(color: Color(0xFF116478)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF116478)),
                  backgroundColor: Colors.white,
                ),
                onPressed: () async {
                  final result = await showDialog<List<int>>(
                    context: context,
                    builder: (context) => MultiSelectDialog<int>(
                      title:
                          AppLocalizations.of(
                            context,
                          )?.translate('filterByEquipment') ??
                          'Filter by Equipment',
                      items: equipment.map((e) => e.id).toList(),
                      initialSelected: _selectedEquipmentIds,
                      labelBuilder: (id) => equipment
                          .firstWhere(
                            (e) => e.id == id,
                            orElse: () => Equipment(
                              id: -1,
                              name: 'Unknown',
                              type: '',
                              salonId: -1,
                            ),
                          )
                          .name,
                      brandColor: const Color(0xFF116478),
                      chipColor: const Color(0xFF8cb2ab),
                    ),
                  );
                  if (result != null)
                    setState(() => _selectedEquipmentIds = result);
                },
              ),
            ),
          if (salons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.filter_list, color: Color(0xFF116478)),
                label: Text(
                  _selectedSalonIds.isEmpty
                      ? 'Filter by Salon'
                      : 'Salon: ' +
                            _selectedSalonIds
                                .map(
                                  (id) =>
                                      salons.firstWhere((s) => s.id == id).name,
                                )
                                .join(', '),
                  style: const TextStyle(color: Color(0xFF116478)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF116478)),
                  backgroundColor: Colors.white,
                ),
                onPressed: () async {
                  final result = await showDialog<List<int>>(
                    context: context,
                    builder: (context) => MultiSelectDialog<int>(
                      title: 'Filter by Salon',
                      items: salons.map((s) => s.id).toList(),
                      initialSelected: _selectedSalonIds,
                      labelBuilder: (id) =>
                          salons.firstWhere((s) => s.id == id).name,
                      brandColor: const Color(0xFF116478),
                      chipColor: const Color(0xFF8cb2ab),
                    ),
                  );
                  if (result != null)
                    setState(() => _selectedSalonIds = result);
                },
              ),
            ),
          // Equipment filter
          if (equipment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.filter_alt, color: Color(0xFF116478)),
                label: Text(
                  _selectedEquipmentIds.isEmpty
                      ? 'Filter by Equipment'
                      : 'Equipment: ' +
                            _selectedEquipmentIds
                                .map(
                                  (id) => equipment
                                      .firstWhere(
                                        (e) => e.id == id,
                                        orElse: () => Equipment(
                                          id: -1,
                                          name: 'Unknown',
                                          type: '',
                                          salonId: -1,
                                        ),
                                      )
                                      .name,
                                )
                                .join(', '),
                  style: const TextStyle(color: Color(0xFF116478)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF116478)),
                  backgroundColor: Colors.white,
                ),
                onPressed: () async {
                  final result = await showDialog<List<int>>(
                    context: context,
                    builder: (context) => MultiSelectDialog<int>(
                      title: 'Filter by Equipment',
                      items: equipment.map((e) => e.id).toList(),
                      initialSelected: _selectedEquipmentIds,
                      labelBuilder: (id) => equipment
                          .firstWhere(
                            (e) => e.id == id,
                            orElse: () => Equipment(
                              id: -1,
                              name: 'Unknown',
                              type: '',
                              salonId: -1,
                            ),
                          )
                          .name,
                      brandColor: const Color(0xFF116478),
                      chipColor: const Color(0xFF8cb2ab),
                    ),
                  );
                  if (result != null)
                    setState(() => _selectedEquipmentIds = result);
                },
              ),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (memberState.status == MemberStatus.loading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8cb2ab)),
                  );
                } else if (memberState.status == MemberStatus.error) {
                  return Center(
                    child: Text(
                      memberState.error ?? 'Failed to load members',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                } else if (filteredMembers.isEmpty) {
                  return Center(
                    child: Text(
                      'No members found.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 18),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref
                      .read(memberProvider.notifier)
                      .fetchMembers(widget.token),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = filteredMembers[index];
                      Color? memberTypeColor;
                      try {
                        final hex = member.memberTypeColor.replaceAll('#', '');
                        memberTypeColor = Color(int.parse('FF$hex', radix: 16));
                      } catch (_) {
                        memberTypeColor = const Color(0xFF116478);
                      }
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 2,
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: memberTypeColor,
                            radius: 16,
                            child: Text(
                              member.memberTypeName.isNotEmpty
                                  ? member.memberTypeName[0].toUpperCase()
                                  : '',
                              style: TextStyle(
                                color: memberTypeColor.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberDetailPage(
                                member: member,
                                salons: salons,
                                equipment: equipment,
                              ),
                            ),
                          ),
                          title: Text(
                            member.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member.email),
                              Text(member.phone),
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: memberTypeColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Text(
                                    member.memberTypeName,
                                    style: TextStyle(
                                      color: memberTypeColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 4,
                                children: [
                                  ...member.assignedSalonIds.map((id) {
                                    final salon = salons.firstWhere(
                                      (s) => s.id == id,
                                      orElse: () => Salon(
                                        id: -1,
                                        name: 'Unknown',
                                        type: '',
                                      ),
                                    );
                                    if (salon.id == -1) return const SizedBox();
                                    return Chip(
                                      label: Text(salon.name),
                                      backgroundColor: const Color(
                                        0xFF8cb2ab,
                                      ).withOpacity(0.2),
                                    );
                                  }),
                                  ...?member.assignedEquipmentIds?.map((id) {
                                    final eq = equipment.firstWhere(
                                      (e) => e.id == id,
                                      orElse: () => Equipment(
                                        id: -1,
                                        name: 'Unknown',
                                        type: '',
                                        salonId: -1,
                                      ),
                                    );
                                    if (eq.id == -1) return const SizedBox();
                                    return Chip(
                                      label: Text(eq.name),
                                      backgroundColor: const Color(
                                        0xFF116478,
                                      ).withOpacity(0.15),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF8cb2ab),
                                ),
                                onPressed: _isDeleting
                                    ? null
                                    : () async {
                                        await showDialog<bool>(
                                          context: context,
                                          builder: (context) => MemberEditDialog(
                                            member: member,
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
                                                ) async {
                                                  final updateResult = await ref
                                                      .read(
                                                        memberProvider.notifier,
                                                      )
                                                      .updateMember(
                                                        Member(
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
                                                        ),
                                                        widget.token,
                                                      );
                                                  if (updateResult == null) {
                                                    Navigator.pop(
                                                      context,
                                                      true,
                                                    );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Member updated successfully',
                                                        ),
                                                        backgroundColor: Color(
                                                          0xFF8cb2ab,
                                                        ),
                                                      ),
                                                    );
                                                    return null;
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                      context,
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
                                                  }
                                                },
                                          ),
                                        );
                                      },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: _isDeleting
                                    ? null
                                    : () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Member'),
                                            content: const Text(
                                              'Are you sure you want to delete this member?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          setState(() => _isDeleting = true);
                                          _recentlyDeleted = member;
                                          _recentlyDeletedIndex = index;
                                          await ref
                                              .read(memberProvider.notifier)
                                              .deleteMember(
                                                member.id,
                                                widget.token,
                                              );
                                          setState(() => _isDeleting = false);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Member deleted',
                                              ),
                                              backgroundColor: Colors.red,
                                              action: SnackBarAction(
                                                label: 'UNDO',
                                                textColor: Color(0xFF8cb2ab),
                                                onPressed: () async {
                                                  if (_recentlyDeleted !=
                                                          null &&
                                                      _recentlyDeletedIndex !=
                                                          null) {
                                                    await ref
                                                        .read(
                                                          memberProvider
                                                              .notifier,
                                                        )
                                                        .addMember(
                                                          _recentlyDeleted!,
                                                          widget.token,
                                                        );
                                                    setState(() {
                                                      _recentlyDeleted = null;
                                                      _recentlyDeletedIndex =
                                                          null;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      },
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF8cb2ab),
        child: const Icon(Icons.add, color: Color(0xFF116478)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => MemberEditDialog(
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
                  ) async {
                    final addResult = await ref
                        .read(memberProvider.notifier)
                        .addMember(
                          Member(
                            id: 0,
                            name: name,
                            phone: phone,
                            email: email,
                            memberTypeId: memberTypeId,
                            memberTypeName: '',
                            memberTypeColor: '#116478',
                            assignedSalonIds: assignedSalonIds,
                            assignedEquipmentIds: assignedEquipmentIds,
                            remainingLessons: remainingLessons,
                            totalDebt: 0.0,
                          ),
                          widget.token,
                        );
                    if (addResult == null) {
                      Navigator.pop(context, true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Member added successfully'),
                          backgroundColor: Color(0xFF8cb2ab),
                        ),
                      );
                      return null;
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(addResult),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return addResult;
                    }
                  },
            ),
          );
        },
      ),
    );
  }
}
