class ProfilePageModel {
  final String name;
  final String iconUrl;
  final String status;
  final String? municipality; // 市町村(近くの友達で使う想定)

  ProfilePageModel({
    required this.name,
    required this.iconUrl,
    required this.status,
    this.municipality,
  });

  // Firestore からの生成
  factory ProfilePageModel.fromFirestore(Map<String, dynamic> data) {
    return ProfilePageModel(
      name: data['name'] ?? '',
      iconUrl: data['iconUrl'] ?? '',
      status: data['status'] ?? '',
      municipality: data['municipality'],
    );
  }

  // JSON -> Model
  factory ProfilePageModel.fromJson(Map<String, dynamic> json) {
    return ProfilePageModel(
      name: json['name'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      status: json['status'] ?? '',
      municipality: json['municipality'],
    );
  }

  // Model -> JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'iconUrl': iconUrl,
      'status': status,
      if (municipality != null) 'municipality': municipality,
    };
  }
}
