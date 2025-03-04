import 'package:cloud_firestore/cloud_firestore.dart';

/// -----------------------------------------
/// 1. プロフィールモデル
/// -----------------------------------------
class ProfilePageModel {
  String name;
  String iconUrl;
  String status; // 一言

  ProfilePageModel({
    required this.name,
    required this.iconUrl,
    required this.status,
  });

  factory ProfilePageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProfilePageModel(
      name: data['name'] ?? '',
      iconUrl: data['iconUrl'] ?? '',
      status: data['status'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name, 'iconUrl': iconUrl, 'status': status};
  }
}
