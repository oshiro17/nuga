import 'dart:convert';
import 'dart:math' as console;
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
      // await _fetchfriendList();
      // await _fetchFriendsOfFriends();
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
    debugPrint('フォローリクエストリスト (キャッシュしない): $_followRequests');
  }

  // -------------------------------
  // 2) フレンドリスト (キャッシュあり)
  // -------------------------------
  // Future<void> _fetchfriendList() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final cached = prefs.getString('friendList_${widget.uid}');
  //   if (cached != null) {
  //     try {
  //       final List decoded = json.decode(cached);
  //       _friendList =
  //           decoded.map<Map<String, String>>((e) {
  //             return {
  //               'uid': e['uid'] ?? '',
  //               'name': e['name'] ?? '',
  //               'iconUrl': e['iconUrl'] ?? '',
  //             };
  //           }).toList();
  //       debugPrint('キャッシュされたフレンドリスト: $_friendList');
  //       setState(() {});
  //       return; // キャッシュがあれば Firebase にアクセスしない
  //     } catch (_) {
  //       debugPrint('フレンドリストのキャッシュ読み込みエラー');
  //     }
  //   } else {
  //     debugPrint('フレンドリストのキャッシュは存在しません');
  //   }

  //   // キャッシュがない場合だけ Firebase アクセス
  //   final snapshot =
  //       await FirebaseFirestore.instance
  //           .collection('users')
  //           .doc(widget.uid)
  //           .collection('friendList')
  //           .get();
  //   final friends =
  //       snapshot.docs.map<Map<String, String>>((doc) {
  //         final data = doc.data();
  //         return {
  //           'uid': doc.id,
  //           'name': data['name'] ?? '',
  //           'iconUrl': data['iconUrl'] ?? '',
  //         };
  //       }).toList();

  //   // キャッシュに保存
  //   await prefs.setString('friendList_${widget.uid}', json.encode(friends));
  //   debugPrint('Firebaseから取得したフレンドリストをキャッシュに保存: $friends');

  //   setState(() {
  //     _friendList = friends;
  //   });
  // }

  // -------------------------------
  // 3) 友達の友達リスト (キャッシュあり)
  // -------------------------------
  // Future<void> _fetchFriendsOfFriends() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final cached = prefs.getString('friends_of_friends_${widget.uid}');
  //   if (cached != null) {
  //     try {
  //       final List decoded = json.decode(cached);
  //       _friendsOfFriends =
  //           decoded.map<Map<String, String>>((e) {
  //             return {
  //               'uid': e['uid'] ?? '',
  //               'name': e['name'] ?? '',
  //               'iconUrl': e['iconUrl'] ?? '',
  //             };
  //           }).toList();
  //       debugPrint('キャッシュされた友達の友達リスト: $_friendsOfFriends');
  //       setState(() {});
  //       return; // キャッシュがあれば Firebase にアクセスしない
  //     } catch (_) {
  //       debugPrint('友達の友達リストのキャッシュ読み込みエラー');
  //     }
  //   } else {
  //     debugPrint('友達の友達リストのキャッシュは存在しません');
  //   }

  //   // キャッシュがない場合、Firebaseへアクセス開始
  //   debugPrint('Firebaseから友達の友達リストを取得します');
  //   List<Map<String, String>> temp = [];
  //   for (var friend in _friendList) {
  //     debugPrint('Firestoreにアクセス: ユーザー ${friend['uid']} の friendList を取得中...');
  //     final snapshot =
  //         await FirebaseFirestore.instance
  //             .collection('users')
  //             .doc(friend['uid'])
  //             .collection('friendList')
  //             .get();

  //     debugPrint(
  //       '友達 ${friend['uid']} の friendList から取得したドキュメント数: ${snapshot.docs.length}',
  //     );
  //     for (var doc in snapshot.docs) {
  //       final data = doc.data();
  //       debugPrint('取得したドキュメント: id=${doc.id}, data=$data');
  //       temp.add({
  //         'uid': doc.id,
  //         'name': data['name'] ?? '',
  //         'iconUrl': data['iconUrl'] ?? '',
  //       });
  //     }
  //   }
  //   // 重複削除（キーは uid とする）
  //   final unique = <String, Map<String, String>>{};
  //   for (var item in temp) {
  //     unique[item['uid'] ?? ''] = item;
  //   }
  //   final result = unique.values.toList();

  //   // キャッシュに保存
  //   await prefs.setString(
  //     'friends_of_friends_${widget.uid}',
  //     json.encode(result),
  //   );
  //   debugPrint('Firebaseから取得した友達の友達リストをキャッシュに保存: $result');

  //   setState(() {
  //     _friendsOfFriends = result;
  //   });
  // }

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
                'name': e['name'] ?? 'namae',
                'iconUrl': e['iconUrl'] ?? '',
              };
            }).toList();
        debugPrint('キャッシュされた近くの友達リスト: $_nearbyFriends');
        setState(() {});
        return; // キャッシュがあれば Firebase にアクセスしない
      } catch (_) {
        debugPrint('近くの友達リストのキャッシュ読み込みエラー');
      }
    } else {
      debugPrint('近くの友達リストのキャッシュは存在しません');
    }
    debugPrint('近くの友達リストのキャッシュは存在しません');

    // まず自分のステータス (ここでは status とする) を取得
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .get();
    if (!userDoc.exists) return;
    final userData = userDoc.data()!;
    final myStatus = userData['city'] ?? '';

    debugPrint('Firebaseから近くの友達リストを取得します');
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where('city', isEqualTo: myStatus)
            .get();

    final nearList =
        snapshot.docs
            .map<Map<String, String>>((doc) {
              final data = doc.data();
              debugPrint('取得したドキュメント: id=${doc.id}, data=${data['name']}');
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
    debugPrint('Firebaseから取得した近くの友達リストをキャッシュに保存: $nearList');

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
      debugPrint('取得したプロフィール: $_profile');
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
