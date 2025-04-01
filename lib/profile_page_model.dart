class ProfilePageModel {
  final String name;
  final String iconUrl;
  final String status;
  final String? city; // 市町村(近くの友達で使う想定)

  ProfilePageModel({
    required this.name,
    required this.iconUrl,
    required this.status,
    this.city,
  });

  // Firestore からの生成
  factory ProfilePageModel.fromFirestore(Map<String, dynamic> data) {
    return ProfilePageModel(
      name: data['name'] ?? '',
      iconUrl: data['iconUrl'] ?? '',
      status: data['status'] ?? '',
      city: data['city'],
    );
  }

  // JSON -> Model
  factory ProfilePageModel.fromJson(Map<String, dynamic> json) {
    return ProfilePageModel(
      name: json['name'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      status: json['status'] ?? '',
      city: json['city'],
    );
  }

  // Model -> JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'iconUrl': iconUrl,
      'status': status,
      if (city != null) 'city': city,
    };
  }
}
