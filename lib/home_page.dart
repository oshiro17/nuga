// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:ringring/friend_add_page.dart';
// import 'package:ringring/friend_chat_page.dart';
// import 'package:ringring/friend_page.dart';
// import 'package:ringring/profile_page.dart';
// import 'package:ringring/profile_page_model.dart';

// /// -----------------------------------------
// /// 2. ホームページ
// /// -----------------------------------------
// class HomePage extends StatefulWidget {
//   final String uid;
//   const HomePage({Key? key, required this.uid}) : super(key: key);

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   int _selectedIndex = 0;
//   ProfilePageModel? _profile;
//   bool _isLoadingProfile = true; // プロフィール読込中かどうか
//   bool _isLoadingFriends = true; // 友達リスト読込中かどうか
//   List<DocumentSnapshot> _friendDocs = []; // キャッシュされた友達情報

//   @override
//   void initState() {
//     super.initState();
//     _loadProfile(); // プロフィール取得
//     _loadFriendList(); // 友達リスト取得（ホームページ生成時のみ）
//   }

//   // Firestoreからユーザーのプロフィールを取得（1度きり）
//   Future<void> _loadProfile() async {
//     try {
//       final doc =
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(widget.uid)
//               .get();

//       if (doc.exists) {
//         setState(() {
//           _profile = ProfilePageModel.fromFirestore(doc);
//         });
//       } else {
//         setState(() {
//           _profile = null;
//         });
//       }
//     } catch (e) {
//       debugPrint('プロフィール読み込みエラー: $e');
//       setState(() {
//         _profile = null;
//       });
//     } finally {
//       setState(() {
//         _isLoadingProfile = false;
//       });
//     }
//   }

//   // Firestoreから友達リストと、各友達の詳細情報をまとめて取得
//   Future<void> _loadFriendList() async {
//     try {
//       // friendlist コレクションから友達のUIDを取得
//       QuerySnapshot snapshot =
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(widget.uid)
//               .collection('friendlist')
//               .get();

//       // 各友達の詳細情報を並列で取得
//       List<Future<DocumentSnapshot>> futures =
//           snapshot.docs.map((doc) {
//             return FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(doc.id)
//                 .get();
//           }).toList();

//       List<DocumentSnapshot> friendDocs = await Future.wait(futures);
//       setState(() {
//         _friendDocs = friendDocs.where((doc) => doc.exists).toList();
//       });
//     } catch (e) {
//       debugPrint('友達リスト読み込みエラー: $e');
//     } finally {
//       setState(() {
//         _isLoadingFriends = false;
//       });
//     }
//   }

//   // BottomNavigationBar のタップ処理
//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // すべてのデータ取得が完了するまでローディング表示
//     if (_isLoadingProfile || _isLoadingFriends) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     // 各ページにキャッシュ済みの友達情報(_friendDocs)とプロフィール(_profile)を渡す
//     final List<Widget> pages = [
//       FriendChatPage(uid: widget.uid, friendDocs: _friendDocs),
//       FriendPage(uid: widget.uid, friendDocs: _friendDocs),
//       FriendAddPage(uid: widget.uid),
//       ProfilePage(
//         uid: widget.uid,
//         profile: _profile,
//         // ProfilePageで更新完了したら、こちらにも新プロフィールを反映
//         onProfileUpdated: (newProfile) {
//           setState(() {
//             _profile = newProfile;
//           });
//         },
//       ),
//     ];

//     return Scaffold(
//       body: IndexedStack(index: _selectedIndex, children: pages),
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _selectedIndex,
//         onTap: _onItemTapped,
//         items: const [
//           BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'チャット'),
//           BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: '友達'),
//           BottomNavigationBarItem(icon: Icon(Icons.group), label: '探す'),
//           BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
//         ],
//       ),
//     );
//   }
// }
