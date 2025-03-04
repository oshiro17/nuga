import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ringring/profile_page_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

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
    // 既存プロフィールがあればその値を使う
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _statusController = TextEditingController(
      text: widget.profile?.status ?? '',
    );
    // アイコン画像は既存データ（URL）をそのまま利用（表示時にImage.networkかImage.fileを切り替える）
    // ※ここでは _iconFile は null のままとする
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 親から新しいprofileが渡された場合はフォームを更新
    if (widget.profile != oldWidget.profile) {
      _nameController.text = widget.profile?.name ?? '';
      _statusController.text = widget.profile?.status ?? '';
      // 既に登録済みのアイコンがあれば、_iconFileはクリア（再選択する場合は更新）
      _iconFile = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  // 画像ピッカーとクロッパーで画像を取得
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // 正方形に設定
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
        // もしパスが "file://" で始まっているなら取り除く
        if (filePath.startsWith('file://')) {
          filePath = filePath.replaceFirst('file://', '');
        }
        setState(() {
          _iconFile = File(filePath);
        });
      }
    }
  }

  // Firestoreに保存（新規 or 更新）
  // ※実際にはFirebase StorageへアップロードしてURLを取得するのが望ましい
  Future<void> _saveProfile() async {
    // ここではシンプルに、画像が選択されていればそのパスを保存
    final newProfile = ProfilePageModel(
      name: _nameController.text.trim(),
      iconUrl: _iconFile?.path ?? widget.profile?.iconUrl ?? '',
      status: _statusController.text.trim(),
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set(newProfile.toFirestore(), SetOptions(merge: true));

      // 保存後、コールバックで親に知らせる
      widget.onProfileUpdated(newProfile);
      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      debugPrint('プロフィール保存時にエラー: $e');
      // 必要に応じてエラー処理
    }
  }

  @override
  Widget build(BuildContext context) {
    // プロフィール未設定 & 編集モードじゃない場合 → 自動的に編集モードへ
    if (widget.profile == null && !_isEditing) {
      _isEditing = true;
    }

    if (_isEditing) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 0),
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
            // ElevatedButton(onPressed: _saveProfile, child: const Text('保存')),
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
            // アイコン画像表示（ローカルファイルがあればそちらを優先）
            _buildProfileIcon(),
            const SizedBox(height: 20),
            Text(
              widget.profile!.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(widget.profile!.status, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            // ElevatedButton(
            //   onPressed: () {
            //     setState(() {
            //       _isEditing = true;
            //     });
            //   },
            //   child: const Text('設定変更'),
            // ),
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
          ],
        ),
      ),
    );
  }

  /// アイコン画像を表示するウィジェット
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
      imageWidget = const CircleAvatar(
        radius: 50,
        child: Icon(Icons.person, size: 50),
      );
    }

    // GestureDetector でラップしてタップ時に _pickImage() を呼ぶ
    return GestureDetector(onTap: _pickImage, child: imageWidget);
  }
}
