import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePageModel {
  String name;
  String iconUrl;
  String status;
  // String? prefecture;
  String? municipality;

  ProfilePageModel({
    required this.name,
    required this.iconUrl,
    required this.status,
    // this.prefecture,
    this.municipality,
  });

  factory ProfilePageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProfilePageModel(
      name: data['name'] ?? '',
      iconUrl: data['iconUrl'] ?? '',
      status: data['status'] ?? '',
      // prefecture: data['prefecture'],
      municipality: data['municipality'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'iconUrl': iconUrl,
      'status': status,
      // if (prefecture != null) 'prefecture': prefecture,
      if (municipality != null) 'municipality': municipality,
    };
  }
}
