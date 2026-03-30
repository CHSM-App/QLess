import 'package:json_annotation/json_annotation.dart';

part 'master_data.g.dart';

@JsonSerializable()
class MasterData {
  // Gender fields
  @JsonKey(name: 'gender_id')
  final int? genderId;
  final String? gender;

   //Blood Group Field
  @JsonKey(name: 'blood_group_id')
  final int? bloodGroupId;

  @JsonKey(name: 'blood_Group_name')
  final String? bloodGroupName;
  // Clinic fields
  @JsonKey(name: 'relation_id')
  final int? relationId;
  final String? relation;
  MasterData({
  this.genderId,
    this.gender,
    this.bloodGroupId,
    this.bloodGroupName,
    this.relationId,
    this.relation
  });
  
  factory MasterData.fromJson(Map<String, dynamic> json) =>
   _$MasterDataFromJson(json);
  

  Map<String, dynamic> toJson() => _$MasterDataToJson(this);

}