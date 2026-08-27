int memberSelfInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double memberSelfDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? memberSelfNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class MemberMeasurement {
  final int id;
  final DateTime? measuredAt;
  final double? height;
  final double? weight;
  final double? waist;
  final double? hip;
  final double? chest;
  final double? arm;
  final double? leg;
  final double? shoulder;
  final double? bodyFatPercentage;

  const MemberMeasurement({
    required this.id,
    this.measuredAt,
    this.height,
    this.weight,
    this.waist,
    this.hip,
    this.chest,
    this.arm,
    this.leg,
    this.shoulder,
    this.bodyFatPercentage,
  });

  factory MemberMeasurement.fromJson(Map<String, dynamic> json) {
    return MemberMeasurement(
      id: memberSelfInt(json['id']),
      measuredAt: DateTime.tryParse((json['measuredAt'] ?? '').toString()),
      height: memberSelfNullableDouble(json['height']),
      weight: memberSelfNullableDouble(json['weight']),
      waist: memberSelfNullableDouble(json['waist']),
      hip: memberSelfNullableDouble(json['hip']),
      chest: memberSelfNullableDouble(json['chest']),
      arm: memberSelfNullableDouble(json['arm']),
      leg: memberSelfNullableDouble(json['leg']),
      shoulder: memberSelfNullableDouble(json['shoulder']),
      bodyFatPercentage: memberSelfNullableDouble(json['bodyFatPercentage']),
    );
  }
}

class MemberSelfProfile {
  final int memberId;
  final String name;
  final String phone;
  final String? email;
  final String? memberTypeName;
  final DateTime? createdAt;
  final int studioId;
  final String studioName;
  final int remainingLessons;
  final double totalDebt;
  final MemberMeasurement? latestMeasurement;

  const MemberSelfProfile({
    required this.memberId,
    required this.name,
    required this.phone,
    required this.email,
    required this.memberTypeName,
    required this.createdAt,
    required this.studioId,
    required this.studioName,
    required this.remainingLessons,
    required this.totalDebt,
    required this.latestMeasurement,
  });

  factory MemberSelfProfile.fromJson(Map<String, dynamic> json) {
    final member = Map<String, dynamic>.from(json['member'] as Map? ?? {});
    final studio = Map<String, dynamic>.from(json['studio'] as Map? ?? {});
    final summary = Map<String, dynamic>.from(json['summary'] as Map? ?? {});
    final memberType = member['memberType'] is Map
        ? Map<String, dynamic>.from(member['memberType'] as Map)
        : null;
    final latestMeasurement = summary['latestMeasurement'] is Map
        ? MemberMeasurement.fromJson(
            Map<String, dynamic>.from(summary['latestMeasurement'] as Map),
          )
        : null;
    return MemberSelfProfile(
      memberId: memberSelfInt(member['id']),
      name: (member['name'] ?? '').toString(),
      phone: (member['phone'] ?? '').toString(),
      email: member['email']?.toString(),
      memberTypeName: memberType?['name']?.toString(),
      createdAt: DateTime.tryParse((member['createdAt'] ?? '').toString()),
      studioId: memberSelfInt(studio['id']),
      studioName: (studio['name'] ?? '').toString(),
      remainingLessons: memberSelfInt(summary['remainingLessons']),
      totalDebt: memberSelfDouble(summary['totalDebt']),
      latestMeasurement: latestMeasurement,
    );
  }
}

class MemberReservation {
  final int id;
  final DateTime? date;
  final String time;
  final String? salonName;
  final String? equipmentName;
  final String? recurrenceType;
  final DateTime? recurrenceEndDate;

  const MemberReservation({
    required this.id,
    required this.date,
    required this.time,
    required this.salonName,
    required this.equipmentName,
    required this.recurrenceType,
    required this.recurrenceEndDate,
  });

  factory MemberReservation.fromJson(Map<String, dynamic> json) {
    final salon = json['salon'] is Map
        ? Map<String, dynamic>.from(json['salon'] as Map)
        : null;
    final equipment = json['equipment'] is Map
        ? Map<String, dynamic>.from(json['equipment'] as Map)
        : null;
    final recurrence = json['recurrence'] is Map
        ? Map<String, dynamic>.from(json['recurrence'] as Map)
        : null;
    return MemberReservation(
      id: memberSelfInt(json['id']),
      date: DateTime.tryParse((json['date'] ?? '').toString()),
      time: (json['time'] ?? '').toString(),
      salonName: salon?['name']?.toString(),
      equipmentName: equipment?['name']?.toString(),
      recurrenceType: recurrence?['type']?.toString(),
      recurrenceEndDate: DateTime.tryParse(
        (recurrence?['endDate'] ?? '').toString(),
      ),
    );
  }
}

class MemberPackageAssignment {
  final int assignmentId;
  final int packageId;
  final String? name;
  final int? lessonCount;
  final double? price;
  final DateTime? assignedAt;
  final double originalPrice;
  final String? discountType;
  final double? discountValue;
  final double finalPrice;

  const MemberPackageAssignment({
    required this.assignmentId,
    required this.packageId,
    required this.name,
    required this.lessonCount,
    required this.price,
    required this.assignedAt,
    required this.originalPrice,
    required this.discountType,
    required this.discountValue,
    required this.finalPrice,
  });

  factory MemberPackageAssignment.fromJson(Map<String, dynamic> json) {
    return MemberPackageAssignment(
      assignmentId: memberSelfInt(json['assignmentId']),
      packageId: memberSelfInt(json['packageId']),
      name: json['name']?.toString(),
      lessonCount: json['lessonCount'] == null
          ? null
          : memberSelfInt(json['lessonCount']),
      price: memberSelfNullableDouble(json['price']),
      assignedAt: DateTime.tryParse((json['assignedAt'] ?? '').toString()),
      originalPrice: memberSelfDouble(json['originalPrice']),
      discountType: json['discountType']?.toString(),
      discountValue: memberSelfNullableDouble(json['discountValue']),
      finalPrice: memberSelfDouble(json['finalPrice']),
    );
  }
}

class MemberPackagesData {
  final int remainingLessons;
  final List<MemberPackageAssignment> packages;

  const MemberPackagesData({
    required this.remainingLessons,
    required this.packages,
  });

  factory MemberPackagesData.fromJson(Map<String, dynamic> json) {
    final rawPackages = json['packages'] is List
        ? json['packages'] as List
        : [];
    return MemberPackagesData(
      remainingLessons: memberSelfInt(json['remainingLessons']),
      packages: rawPackages
          .whereType<Map>()
          .map(
            (item) => MemberPackageAssignment.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

class MemberAttendance {
  final int id;
  final DateTime? date;
  final int? reservationId;
  final String? salonName;
  final String? instructorName;

  const MemberAttendance({
    required this.id,
    required this.date,
    required this.reservationId,
    required this.salonName,
    required this.instructorName,
  });

  factory MemberAttendance.fromJson(Map<String, dynamic> json) {
    final salon = json['salon'] is Map
        ? Map<String, dynamic>.from(json['salon'] as Map)
        : null;
    final instructor = json['instructor'] is Map
        ? Map<String, dynamic>.from(json['instructor'] as Map)
        : null;
    return MemberAttendance(
      id: memberSelfInt(json['id']),
      date: DateTime.tryParse((json['date'] ?? '').toString()),
      reservationId: json['reservationId'] == null
          ? null
          : memberSelfInt(json['reservationId']),
      salonName: salon?['name']?.toString(),
      instructorName: instructor?['name']?.toString(),
    );
  }
}

class MemberPayment {
  final int id;
  final double amount;
  final DateTime? date;
  final String? paymentMethodName;

  const MemberPayment({
    required this.id,
    required this.amount,
    required this.date,
    required this.paymentMethodName,
  });

  factory MemberPayment.fromJson(Map<String, dynamic> json) {
    final method = json['paymentMethod'] is Map
        ? Map<String, dynamic>.from(json['paymentMethod'] as Map)
        : null;
    return MemberPayment(
      id: memberSelfInt(json['id']),
      amount: memberSelfDouble(json['amount']),
      date: DateTime.tryParse((json['date'] ?? '').toString()),
      paymentMethodName: method?['name']?.toString(),
    );
  }
}

class MemberPaymentsData {
  final double totalDebt;
  final List<MemberPayment> payments;

  const MemberPaymentsData({required this.totalDebt, required this.payments});

  factory MemberPaymentsData.fromJson(Map<String, dynamic> json) {
    final rawPayments = json['payments'] is List
        ? json['payments'] as List
        : [];
    return MemberPaymentsData(
      totalDebt: memberSelfDouble(json['totalDebt']),
      payments: rawPayments
          .whereType<Map>()
          .map(
            (item) => MemberPayment.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}
