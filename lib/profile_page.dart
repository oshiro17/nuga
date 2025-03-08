import 'dart:convert'; // ★ JSONエンコード/デコード用
import 'package:shared_preferences/shared_preferences.dart'; // ★ SharedPreferences用
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:ringring/profile_page_model.dart';
import 'package:ringring/location_edit_page.dart'; // ★ 位置情報編集ページ

class ProfilePage extends StatefulWidget {
  final String uid;
  final ProfilePageModel? profile;
  final Function(ProfilePageModel) onProfileUpdated;

  const ProfilePage({
    Key? key,
    required this.uid,
    required this.profile,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;

  late TextEditingController _nameController;
  late TextEditingController _statusController;

  // 画像ファイル（ローカルの一時ファイル）
  File? _iconFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _statusController = TextEditingController(
      text: widget.profile?.status ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile != oldWidget.profile) {
      _nameController.text = widget.profile?.name ?? '';
      _statusController.text = widget.profile?.status ?? '';
      _iconFile = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  // 画像選択＆トリム
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

  // 保存処理（画像アップロード → Firestore + SharedPreferencesキャッシュ更新）
  Future<void> _saveProfile() async {
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
        imageUrl = widget.profile?.iconUrl ?? '';
      }
    } else {
      imageUrl = widget.profile?.iconUrl ?? '';
    }

    final newProfile = ProfilePageModel(
      name: _nameController.text.trim(),
      iconUrl: imageUrl,
      status: _statusController.text.trim(),
      municipality: widget.profile?.municipality, // 位置情報を保持する場合
    );

    try {
      // 1) Firestoreに保存
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set(newProfile.toFirestore(), SetOptions(merge: true));

      // 2) SharedPreferencesのキャッシュを更新
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'profile_${widget.uid}';
      // ProfilePageModel → JSON文字列に変換
      final jsonString = json.encode(newProfile.toJson());
      await prefs.setString(cacheKey, jsonString);

      // 3) 呼び出し元へのコールバック
      widget.onProfileUpdated(newProfile);

      // 4) 編集モードを終了して表示モードに戻す
      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      debugPrint('プロフィール保存時にエラー: $e');
    }
  }

  /// アイコン画像表示（タップで _pickImage）
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
    } else if (widget.profile != null && widget.profile!.iconUrl.isNotEmpty) {
      if (widget.profile!.iconUrl.startsWith('http')) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            widget.profile!.iconUrl,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      } else {
        // 端末ローカルのパスの場合
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.file(
            File(widget.profile!.iconUrl),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      }
    } else {
      // アイコン未設定
      imageWidget = const CircleAvatar(
        radius: 50,
        child: Icon(Icons.person, size: 50),
      );
    }
    return GestureDetector(onTap: _pickImage, child: imageWidget);
  }

  @override
  Widget build(BuildContext context) {
    // プロフィールが null なら編集モードを強制
    if (widget.profile == null && !_isEditing) {
      _isEditing = true;
    }

    // 編集モード
    if (_isEditing) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              'プロフィール',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
            ),
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
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                '保存',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            if (widget.profile != null)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                  });
                },
                child: const Text('キャンセル'),
              ),
          ],
        ),
      );
    }

    // 表示モード
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 位置情報編集ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final updatedProfile = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => LocationEditPage(
                              uid: widget.uid,
                              profile: widget.profile,
                            ),
                      ),
                    );
                    if (updatedProfile != null) {
                      // 位置情報が変更されたら更新
                      widget.onProfileUpdated(updatedProfile);
                      setState(() {});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.white,
                  ),
                  child: const Icon(Icons.location_on, color: Colors.black),
                ),
                Text(
                  widget.profile?.municipality ?? '生息地',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(width: 2),
              ],
            ),
            const SizedBox(height: 20),
            _buildProfileIcon(),
            const SizedBox(height: 20),
            Text(
              widget.profile!.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(widget.profile!.status, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),

            // プロフィール編集ボタン
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                '編集',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),
            // ここに他の情報やボタンがあれば追加
          ],
        ),
      ),
    );
  }
}
