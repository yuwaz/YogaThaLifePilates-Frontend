import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum MemberStatus { initial, loading, loaded, error }

const String BASE_URL = 'http://204.168.168.23:3000/settings/members';

class MemberState {
  final List<Member> members;
  final MemberStatus status;
  final String? error;

  MemberState({
    required this.members,
    this.status = MemberStatus.initial,
    this.error,
  });

  MemberState copyWith({
    List<Member>? members,
    MemberStatus? status,
    String? error,
  }) {
    return MemberState(
      members: members ?? this.members,
      status: status ?? this.status,
      error: error,
    );
  }
}

final memberProvider = StateNotifierProvider<MemberNotifier, MemberState>(
  (ref) => MemberNotifier(),
);

class MemberNotifier extends StateNotifier<MemberState> {
  MemberNotifier() : super(MemberState(members: []));

  Future<void> fetchMembers(String token) async {
    state = state.copyWith(status: MemberStatus.loading, error: null);
    try {
      final response = await http.get(
        Uri.parse(BASE_URL),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        state = state.copyWith(
          members: data.map((e) => Member.fromJson(e)).toList(),
          status: MemberStatus.loaded,
        );
      } else {
        state = state.copyWith(
          status: MemberStatus.error,
          error: 'Failed to fetch members',
        );
      }
    } catch (e) {
      state = state.copyWith(status: MemberStatus.error, error: e.toString());
    }
  }

  Future<String?> addMember(Member member, String token) async {
    state = state.copyWith(status: MemberStatus.loading, error: null);
    try {
      if (!member.phone.startsWith('+90')) {
        state = state.copyWith(
          status: MemberStatus.error,
          error: 'Phone number must start with +90',
        );
        return 'Phone number must start with +90';
      }
      final response = await http.post(
        Uri.parse(BASE_URL),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': member.name,
          'phone': member.phone,
          'email': member.email,
          'memberTypeId': member.memberTypeId,
          'assignedSalonIds': member.assignedSalonIds,
          'assignedEquipmentIds': member.assignedEquipmentIds ?? [],
        }),
      );
      if (response.statusCode == 201) {
        await fetchMembers(token);
        return null;
      } else {
        final error = json.decode(response.body);
        state = state.copyWith(
          status: MemberStatus.error,
          error: error['message'] ?? 'Failed to add member',
        );
        return error['message'] ?? 'Failed to add member';
      }
    } catch (e) {
      state = state.copyWith(status: MemberStatus.error, error: e.toString());
      return e.toString();
    }
  }

  Future<String?> updateMember(Member member, String token) async {
    state = state.copyWith(status: MemberStatus.loading, error: null);
    try {
      if (!member.phone.startsWith('+90')) {
        state = state.copyWith(
          status: MemberStatus.error,
          error: 'Phone number must start with +90',
        );
        return 'Phone number must start with +90';
      }
      final response = await http.put(
        Uri.parse('[200~$BASE_URL/${member.id}[201~'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': member.name,
          'phone': member.phone,
          'email': member.email,
          'memberTypeId': member.memberTypeId,
          'assignedSalonIds': member.assignedSalonIds,
          'assignedEquipmentIds': member.assignedEquipmentIds ?? [],
        }),
      );
      if (response.statusCode == 200) {
        await fetchMembers(token);
        return null;
      } else {
        final error = json.decode(response.body);
        state = state.copyWith(
          status: MemberStatus.error,
          error: error['message'] ?? 'Failed to update member',
        );
        return error['message'] ?? 'Failed to update member';
      }
    } catch (e) {
      state = state.copyWith(status: MemberStatus.error, error: e.toString());
      return e.toString();
    }
  }

  Future<void> deleteMember(int id, String token) async {
    state = state.copyWith(status: MemberStatus.loading, error: null);
    try {
      final response = await http.delete(
        Uri.parse('$BASE_URL/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 204) {
        state = state.copyWith(
          members: state.members.where((m) => m.id != id).toList(),
          status: MemberStatus.loaded,
        );
      } else {
        state = state.copyWith(
          status: MemberStatus.error,
          error: 'Failed to delete member',
        );
      }
    } catch (e) {
      state = state.copyWith(status: MemberStatus.error, error: e.toString());
    }
  }
}
