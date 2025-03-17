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
//       // FriendChatPage(uid: widget.uid, friendDocs: _friendDocs),
//       // FriendPage(uid: widget.uid, friendDocs: _friendDocs),
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
//           // BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'チャット'),
//           // BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: '友達'),
//           BottomNavigationBarItem(icon: Icon(Icons.group), label: '探す'),
//           BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
//         ],
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ProfilePageModel は別ファイルか同ファイルか適宜
import 'profile_page_model.dart';

import 'friend_add_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final String uid;
  const HomePage({Key? key, required this.uid}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // UI
  int _selectedIndex = 0;
  bool _isLoading = true;

  // データ
  ProfilePageModel? _profile;
  List<Map<String, String>> _followRequests = [];
  List<Map<String, String>> _friendList = [];
  List<Map<String, String>> _friendsOfFriends = [];
  List<Map<String, String>> _nearbyFriends = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 全データをまとめて取得
  Future<void> _loadData() async {
    try {
      await _fetchProfile();
      await _fetchFollowRequests();
      await _fetchFriendList();
      await _fetchFriendsOfFriends();
      await _fetchNearbyFriends();
    } catch (e) {
      debugPrint('データ取得エラー: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // -------------------------------
  // 1) フォローリクエストリスト (キャッシュしない)
  // -------------------------------
  Future<void> _fetchFollowRequests() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('follow_request_list')
            .get();

    // final requests =
    //     snapshot.docs.map((doc) {
    //       final data = doc.data();
    //       return {
    //         'uid': doc.id,
    //         'name': data['name'] ?? '',
    //         'iconUrl': data['iconUrl'] ?? '',
    //       };
    //     }).toList();

    // setState(() {
    //   _followRequests = requests;
    // });
    final requests =
        snapshot.docs.map<Map<String, String>>((doc) {
          final data = doc.data();
          return {
            'uid': doc.id,
            'name': data['name']?.toString() ?? '',
            'iconUrl': data['iconUrl']?.toString() ?? '',
          };
        }).toList();

    setState(() {
      _followRequests = requests;
    });
  }

  // -------------------------------
  // 2) フレンドリスト (キャッシュあり)
  // -------------------------------
  Future<void> _fetchFriendList() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('friend_list_${widget.uid}');
    if (cached != null) {
      try {
        final List decoded = json.decode(cached);
        _friendList =
            decoded.map<Map<String, String>>((e) {
              return {
                'uid': e['uid'] ?? '',
                'name': e['name'] ?? '',
                'iconUrl': e['iconUrl'] ?? '',
              };
            }).toList();
        setState(() {});
        return; // キャッシュがあれば Firebase に行かない
      } catch (_) {
        debugPrint('フレンドリストのキャッシュ読み込みエラー');
      }
    }

    // キャッシュがない場合だけ Firebase アクセス
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('friend_list')
            .get();
    final friends =
        snapshot.docs.map<Map<String, String>>((doc) {
          final data = doc.data();
          return {
            'uid': doc.id,
            'name': data['name'] ?? '',
            'iconUrl': data['iconUrl'] ?? '',
          };
        }).toList();

    // キャッシュに保存
    await prefs.setString('friend_list_${widget.uid}', json.encode(friends));

    setState(() {
      _friendList = friends;
    });
  }

  // -------------------------------
  // 3) 友達の友達リスト (キャッシュあり)
  // -------------------------------
  Future<void> _fetchFriendsOfFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('friends_of_friends_${widget.uid}');
    if (cached != null) {
      try {
        final List decoded = json.decode(cached);
        _friendsOfFriends =
            decoded.map<Map<String, String>>((e) {
              return {
                'uid': e['uid'] ?? '',
                'name': e['name'] ?? '',
                'iconUrl': e['iconUrl'] ?? '',
              };
            }).toList();
        setState(() {});
        return; // キャッシュがあれば Firebase に行かない
      } catch (_) {
        debugPrint('友達の友達リストのキャッシュ読み込みエラー');
      }
    }

    // キャッシュがない場合のみ Firebase へ
    List<Map<String, String>> temp = [];
    for (var friend in _friendList) {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(friend['uid'])
              .collection('friend_list')
              .get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        temp.add({
          'uid': doc.id,
          'name': data['name'] ?? '',
          'iconUrl': data['iconUrl'] ?? '',
        });
      }
    }
    // 重複や自分・既存フレンドは除外してもOK
    // ここでは単純に重複削除だけしておく
    final unique = <String, Map<String, String>>{};
    for (var item in temp) {
      unique[item['uid'] ?? ''] = item;
    }
    final result = unique.values.toList();

    // キャッシュに保存
    await prefs.setString(
      'friends_of_friends_${widget.uid}',
      json.encode(result),
    );

    setState(() {
      _friendsOfFriends = result;
    });
  }

  // -------------------------------
  // 4) 近くの友達リスト (キャッシュあり)
  // -------------------------------
  Future<void> _fetchNearbyFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('nearby_friends_${widget.uid}');
    if (cached != null) {
      try {
        final List decoded = json.decode(cached);
        _nearbyFriends =
            decoded.map<Map<String, String>>((e) {
              return {
                'uid': e['uid'] ?? '',
                'name': e['name'] ?? '',
                'iconUrl': e['iconUrl'] ?? '',
              };
            }).toList();
        setState(() {});
        return; // キャッシュがあれば Firebase に行かない
      } catch (_) {
        debugPrint('近くの友達リストのキャッシュ読み込みエラー');
      }
    }

    // まず自分のステータス or municipality を取得 (ここでは status とする)
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .get();
    if (!userDoc.exists) return;
    final userData = userDoc.data()!;
    final myStatus = userData['status'] ?? '';

    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where('status', isEqualTo: myStatus)
            .get();

    final nearList =
        snapshot.docs
            .map<Map<String, String>>((doc) {
              final data = doc.data();
              return {
                'uid': doc.id,
                'name': data['name'] ?? '',
                'iconUrl': data['iconUrl'] ?? '',
              };
            })
            .where((item) => item['uid'] != widget.uid) // 自分は除外
            .toList();

    // キャッシュに保存
    await prefs.setString(
      'nearby_friends_${widget.uid}',
      json.encode(nearList),
    );

    setState(() {
      _nearbyFriends = nearList;
    });
  }

  // -------------------------------
  // プロフィール(例)
  // -------------------------------
  Future<void> _fetchProfile() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _profile = ProfilePageModel.fromFirestore(data);
      });
    }
  }

  // ------------------------------------------------
  // Bottom Navigation
  // ------------------------------------------------
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ------------------------------------------------
  // build
  // ------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // FriendAddPage と ProfilePage を切り替え
    final pages = [
      FriendAddPage(
        uid: widget.uid,
        followRequests: _followRequests,
        friendList: _friendList,
        friendsOfFriends: _friendsOfFriends,
        nearbyFriends: _nearbyFriends,
      ),
      ProfilePage(
        uid: widget.uid,
        profile: _profile,
        onProfileUpdated: (updated) {
          // 例: プロフィールが更新されたら state に反映
          setState(() {
            _profile = updated;
          });
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: '友達追加'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
        ],
      ),
    );
  }
}
