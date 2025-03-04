import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ringring/profile_page.dart';
import 'package:ringring/profile_page_model.dart';

/// -----------------------------------------
/// 2. ホームページ
/// -----------------------------------------
class HomePage extends StatefulWidget {
  final String uid;
  const HomePage({Key? key, required this.uid}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  ProfilePageModel? _profile;
  bool _isLoading = true; // プロフィール読込中かどうか

  @override
  void initState() {
    super.initState();
    _loadProfile(); // 初回1回だけFirestoreから取得
  }

  // Firestoreからユーザーのプロフィールを取得（1度きり）
  Future<void> _loadProfile() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .get();

      if (doc.exists) {
        setState(() {
          _profile = ProfilePageModel.fromFirestore(doc);
        });
      } else {
        // ドキュメントが存在しない場合、プロフィール未設定
        setState(() {
          _profile = null;
        });
      }
    } catch (e) {
      // 取得失敗時などのエラーハンドリングを必要に応じて行う
      debugPrint('エラーが発生しました: $e');
      setState(() {
        _profile = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // BottomNavigationBarのタップ
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // それぞれのページをリスト化（_profile を渡す）
    final List<Widget> pages = [
      FriendChatPage(uid: widget.uid),
      FriendAddPage(uid: widget.uid),
      ProfilePage(
        uid: widget.uid,
        profile: _profile,
        // ProfilePageで更新完了したら、こちらにも新プロフィールを反映
        onProfileUpdated: (newProfile) {
          setState(() {
            _profile = newProfile;
          });
        },
      ),
    ];

    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'チャット'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: '友達'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
        ],
      ),
    );
  }
}

/// -----------------------------------------
/// 4. 仮のチャット画面
/// -----------------------------------------
class FriendChatPage extends StatelessWidget {
  final String uid;
  const FriendChatPage({Key? key, required this.uid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('チャット画面\nUID: $uid', textAlign: TextAlign.center),
    );
  }
}

/// -----------------------------------------
/// 5. 仮の友達一覧・追加画面
/// -----------------------------------------
class FriendAddPage extends StatelessWidget {
  final String uid;
  const FriendAddPage({Key? key, required this.uid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('友達一覧・追加画面\nUID: $uid', textAlign: TextAlign.center),
    );
  }
}

/// -----------------------------------------
/// 6. 実行例（Firebase初期化）
/// -----------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // テスト用に uid を固定して例示
  const String testUid = "example_uid_123";

  runApp(MaterialApp(home: HomePage(uid: testUid)));
}
