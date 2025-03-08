import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ringring/home_page.dart';

class SettingIdPage extends StatefulWidget {
  final String uid;
  const SettingIdPage({Key? key, required this.uid}) : super(key: key);

  @override
  State<SettingIdPage> createState() => _SettingIdPageState();
}

class _SettingIdPageState extends State<SettingIdPage> {
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadExistingId();
  }

  Future<void> _loadExistingId() async {
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .get();
      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null &&
            data['id'] != null &&
            (data['id'] as String).isNotEmpty) {
          // IDが既に設定済みなら、ホームページへ遷移する
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(uid: widget.uid),
              ),
            );
          }
          return; // ここで早期リターン
        }
        // ID未設定の場合は、テキストフィールドに反映
        if (data != null && data['id'] != null) {
          _idController.text = data['id'];
        }
      }
    } catch (e) {
      debugPrint('既存ID読み込みエラー: $e');
    }
  }

  Future<void> _saveId() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    final newId = _idController.text.trim();

    if (newId.isEmpty) {
      setState(() {
        _errorMessage = 'IDを入力してください';
        _isLoading = false;
      });
      return;
    }

    try {
      // 同じ id を持つドキュメントを検索（ただし、現在のユーザーのものは除外）
      QuerySnapshot query =
          await FirebaseFirestore.instance
              .collection('users')
              .where('id', isEqualTo: newId)
              .get();

      bool idTaken = false;
      for (var doc in query.docs) {
        if (doc.id != widget.uid) {
          idTaken = true;
          break;
        }
      }

      if (idTaken) {
        setState(() {
          _errorMessage = 'このIDは既に使用されています。';
          _isLoading = false;
        });
        return;
      }

      // 問題なければ、ユーザーのドキュメントに id フィールドを更新
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'id': newId,
      }, SetOptions(merge: true));

      // 保存成功後はページを閉じるなどの処理
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(uid: widget.uid)),
        );
      }
    } catch (e) {
      debugPrint('ID保存時エラー: $e');
      setState(() {
        _errorMessage = 'エラーが発生しました。もう一度お試しください。';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ID設定')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'ユーザーID',
                hintText: '希望のIDを入力してください',
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _saveId, child: const Text('決定')),
          ],
        ),
      ),
    );
  }
}
