import 'package:json_annotation/json_annotation.dart';

part 'family_member.g.dart';

@JsonSerializable()
class FamilyMember {
  @JsonKey(name: 'member_id')
  final int? memberId;

  /// Maps to DB column: name
  @JsonKey(name: 'name')
  final String? memberName;

  /// Maps to DB column: Gender_id  (sent on insert/update)
  @JsonKey(name: 'Gender_id')
  final int? genderId;

  /// Maps to DB column: Gender  (received on fetch — display label)
  @JsonKey(name: 'Gender')
  final String? genderName; // ← fixed: was int?, must be String?

  /// Maps to DB column: DOB
  @JsonKey(name: 'DOB')
  final DateTime? dob;

  /// Maps to DB column: relation_id  (sent on insert/update)
  @JsonKey(name: 'relation_id')
  final int? relationId;

  /// Maps to DB column: relation  (received on fetch — display label)
  @JsonKey(name: 'relation')
  final String? relationName;

  /// Maps to DB column: mobile_no
  @JsonKey(name: 'mobile_no')
  final String? mobileNo;

  const FamilyMember({
    this.memberId,
    this.memberName,
    this.genderId,
    this.genderName,
    this.dob,
    this.relationId,
    this.relationName,
    this.mobileNo,
  });

  /// Avatar letter for list tiles
  String get avatarLetter =>
      (memberName != null && memberName!.isNotEmpty)
          ? memberName![0].toUpperCase()
          : '?';

  factory FamilyMember.fromJson(Map<String, dynamic> json) =>
      _$FamilyMemberFromJson(json);

  Map<String, dynamic> toJson() => _$FamilyMemberToJson(this);
}