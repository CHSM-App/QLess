import 'package:json_annotation/json_annotation.dart';

part 'family_member.g.dart';

@JsonSerializable()
class FamilyMember {
  @JsonKey(name: 'family_id')
  final int? familyId;

  @JsonKey(name: 'member_id')
  final int? memberId;

  @JsonKey(name: 'name')
  final String? memberName;

  @JsonKey(name: 'Gender_id')
  final int? genderId;

  @JsonKey(name: 'Gender')
  final String? genderName; 

  @JsonKey(name: 'DOB')
  final DateTime? dob;

  @JsonKey(name: 'relation_id')
  final int? relationId;

  @JsonKey(name: 'relation')
  final String? relationName;

  @JsonKey(name: 'mobile_no')
  final String? mobileNo;

  const FamilyMember({
    this.familyId,
    this.memberId,
    this.memberName,
    this.genderId,
    this.genderName,
    this.dob,
    this.relationId,
    this.relationName,
    this.mobileNo,
  });

  String get avatarLetter =>
      (memberName != null && memberName!.isNotEmpty)
          ? memberName![0].toUpperCase()
          : '?';

  factory FamilyMember.fromJson(Map<String, dynamic> json) =>
      _$FamilyMemberFromJson(json);

  Map<String, dynamic> toJson() => _$FamilyMemberToJson(this);
}
