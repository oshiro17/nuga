import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class ProfileEditPage extends StatefulWidget {
  final String uid;
  final String iconUrl;
  final String name;
  final String status;

  const ProfileEditPage({
    Key? key,
    required this.uid,
    required this.iconUrl,
    required this.name,
    required this.status,
  }) : super(key: key);

  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late TextEditingController _nameController;
  late TextEditingController _statusController;
  File? _iconFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _statusController = TextEditingController(text: widget.status);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  /// 画像選択＆トリミング処理
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '画像をトリム',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: '画像をトリム'),
        ],
      );
      if (croppedFile != null) {
        String filePath = croppedFile.path;
        if (filePath.startsWith('file://')) {
          filePath = filePath.replaceFirst('file://', '');
        }
        setState(() {
          _iconFile = File(filePath);
        });
      }
    }
  }

  /// アイコン画像のウィジェット構築（タップで画像選択）
  Widget _buildProfileIcon() {
    Widget imageWidget;
    if (_iconFile != null) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.file(
          _iconFile!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } else if (widget.iconUrl.isNotEmpty) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.network(
          widget.iconUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } else {
      imageWidget = const CircleAvatar(
        radius: 50,
        child: Icon(Icons.person, size: 50),
      );
    }
    return GestureDetector(onTap: _pickImage, child: imageWidget);
  }

  /// 保存処理：画像アップロード → Firestore 更新 → SharedPreferences のキャッシュ更新
  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });

    String? imageUrl;
    if (_iconFile != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${widget.uid}.jpg');
        final uploadTask = storageRef.putFile(_iconFile!);
        await uploadTask.whenComplete(() {});
        imageUrl = await storageRef.getDownloadURL();
      } catch (e) {
        debugPrint('画像アップロードエラー: $e');
        imageUrl = widget.iconUrl;
      }
    } else {
      imageUrl = widget.iconUrl;
    }

    final newProfileData = {
      'name': _nameController.text.trim(),
      'status': _statusController.text.trim(),
      'iconUrl': imageUrl,
    };

    try {
      // 1) Firestore に保存（既存のデータにマージ）
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set(newProfileData, SetOptions(merge: true));

      // 2) SharedPreferences のキャッシュ更新
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'profile_${widget.uid}';
      await prefs.setString(cacheKey, json.encode(newProfileData));

      // 3) 保存完了後、前の画面に結果を返して戻る
      Navigator.pop(context, newProfileData);
    } catch (e) {
      debugPrint('プロフィール保存エラー: $e');
      // 必要に応じてエラーダイアログなどを表示する処理を追加
    }
    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール編集')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildProfileIcon(),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名前'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _statusController,
              decoration: const InputDecoration(labelText: '一言'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 24.0,
                ),
              ),
              child:
                  _isSaving
                      ? const CircularProgressIndicator()
                      : const Text(
                        '保存',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // キャンセル時はそのまま前の画面に戻る
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 24.0,
                ),
              ),
              child: const Text('キャンセル'),
            ),
          ],
        ),
      ),
    );
  }
}
