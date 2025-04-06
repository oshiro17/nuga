// profile_page.dart
import 'package:flutter/material.dart';
import 'package:ringring/profile_edit_page.dart';

class ProfilePage extends StatelessWidget {
  final String uid;
  final String iconUrl;
  final String name;
  final String status;
  final VoidCallback? onProfileUpdated;

  const ProfilePage({
    Key? key,
    required this.uid,
    required this.iconUrl,
    required this.name,
    required this.status,
    this.onProfileUpdated,
  }) : super(key: key);

  // 編集ページへ遷移する処理
  void _navigateToEditPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProfileEditPage(
              uid: uid,
              iconUrl: iconUrl,
              name: name,
              status: status,
            ),
      ),
    ).then((_) {
      // 編集後、更新用のコールバックがあれば実行
      if (onProfileUpdated != null) {
        onProfileUpdated!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEditPage(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage:
                    iconUrl.isNotEmpty ? NetworkImage(iconUrl) : null,
                child:
                    iconUrl.isEmpty ? const Icon(Icons.person, size: 50) : null,
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(status, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              // 横幅いっぱいの白いボタン（黒文字、丸い角）
              Container(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white, // テキストの色
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  onPressed: () {},
                  child: const Text('プロフィール編集'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// プロフィール編集用の仮実装ページ（実際のフォーム実装は必要に応じて実装してください）
