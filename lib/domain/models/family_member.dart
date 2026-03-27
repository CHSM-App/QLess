import 'package:json_annotation/json_annotation.dart';

part 'family_member.g.dart';

enum Gender {
  @JsonValue('male')
  male,
  @JsonValue('female')
  female,
  @JsonValue('other')
  other,
}

enum Relation {
  @JsonValue('self')
  self,
  @JsonValue('spouse')
  spouse,
  @JsonValue('child')
  child,
  @JsonValue('parent')
  parent,
  @JsonValue('sibling')
  sibling,
  @JsonValue('other')
  other,
}

@JsonSerializable()
class FamilyMember {
  @JsonKey(name: 'member_id')
  final int? memberId;

  @JsonKey(name: 'member_name')
  final String? memberName;

  @JsonKey(name: 'gender')
  final Gender? gender;

  @JsonKey(name: 'date_of_birth')
  final String? dateOfBirth;

  @JsonKey(name: 'relation')
  final Relation? relation;

  @JsonKey(name: 'mobile_number')
  final String? mobileNumber;

  @JsonKey(name: 'age')
  final int? age;

  FamilyMember({
    this.memberId,
    this.memberName,
    this.gender,
    this.dateOfBirth,
    this.relation,
    this.mobileNumber,
    this.age,
  });

  /// Returns display label for gender
  String get genderLabel {
    switch (gender) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
      default:
        return '';
    }
  }

  /// Returns display label for relation
  String get relationLabel {
    switch (relation) {
      case Relation.self:
        return 'Self';
      case Relation.spouse:
        return 'Spouse';
      case Relation.child:
        return 'Child';
      case Relation.parent:
        return 'Parent';
      case Relation.sibling:
        return 'Sibling';
      case Relation.other:
        return 'Other';
      default:
        return '';
    }
  }

  /// Returns first letter of name for avatar
  String get avatarLetter =>
      (memberName != null && memberName!.isNotEmpty)
          ? memberName![0].toUpperCase()
          : '?';

  factory FamilyMember.fromJson(Map<String, dynamic> json) =>
      _$FamilyMemberFromJson(json);

  Map<String, dynamic> toJson() => _$FamilyMemberToJson(this);
}
