import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePageModel {
  String name;
  String iconUrl;
  String status;
  String? municipality;

  ProfilePageModel({
    required this.name,
    required this.iconUrl,
    required this.status,
    this.municipality,
  });

  factory ProfilePageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProfilePageModel(
      name: data['name'] ?? '',
      iconUrl: data['iconUrl'] ?? '',
      status: data['status'] ?? '',
      municipality: data['municipality'],
    );
  }

  factory ProfilePageModel.fromJson(Map<String, dynamic> json) {
    return ProfilePageModel(
      name: json['name'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      status: json['status'] ?? '',
      municipality: json['municipality'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'iconUrl': iconUrl,
      'status': status,
      if (municipality != null) 'municipality': municipality,
    };
  }

  // 既存の Firestore 用シリアライズメソッド（内容は toJson と同じ）
  Map<String, dynamic> toFirestore() {
    return toJson();
  }
}
