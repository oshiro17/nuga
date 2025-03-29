import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ringring/play_request_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 既存の各ページのインポート
import 'profile_page_model.dart';
import 'friend_add_page.dart';
import 'profile_page.dart';
import 'friend_page.dart';

// 日付が同じかどうかを比較するヘルパー関数
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

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

  // 友達チャット用 Firestore の DocumentSnapshot のリスト
  List<DocumentSnapshot> _friendDocs = [];

  // PlayRequest 用のデータ
  int _requestsPossible = 1;
  List<String> _sendList = [];
  List<String> _incomingPlayRequests = [];
  DateTime? _lastPlayRequestDate;
  StreamSubscription? _playRequestsSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupPlayRequestsListener();
  }

  @override
  void dispose() {
    _playRequestsSubscription?.cancel();
    super.dispose();
  }

  // 全データをまとめて取得
  Future<void> _loadData() async {
    try {
      await _fetchProfile();
      await _fetchFollowRequests();
      await _fetchFriendList();
      await _fetchFriendsOfFriends();
      await _fetchNearbyFriends();
      await _fetchSendList();
    } catch (e) {
      debugPrint('データ取得エラー: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 1) フォローリクエストリスト（キャッシュなし）
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
    debugPrint('フォローリクエストリスト: $_followRequests');
  }

  // 2) フレンドリスト（キャッシュなしで毎回取得）
  Future<void> _fetchFriendList() async {
    // FirestoreのfriendListサブコレクションから友達のuidを取得
    final friendListSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('friendList')
            .get();

    final friendUIDs = friendListSnapshot.docs.map((doc) => doc.id).toList();

    // 取得したuidを元に、usersコレクションから最新情報を取得
    final List<Map<String, String>> friends = await Future.wait(
      friendUIDs.map((friendUID) async {
        final userDocSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(friendUID)
                .get();
        final data = userDocSnapshot.data() as Map<String, dynamic>;
        return {
          'uid': friendUID,
          'name': data['name'] ?? '',
          'iconUrl': data['iconUrl'] ?? '',
        };
      }),
    );

    debugPrint('Firebaseから取得したフレンドリスト: $friends');

    setState(() {
      _friendList = friends;
    });
  }

  // 3) 友達の友達リスト（キャッシュあり＋30回に1回はFirebase更新）
  Future<void> _fetchFriendsOfFriends() async {
    final prefs = await SharedPreferences.getInstance();
    int fetchCount = prefs.getInt('friendsOfFriends_fetchCount') ?? 0;
    fetchCount++;
    await prefs.setInt('friendsOfFriends_fetchCount', fetchCount);

    if (fetchCount % 30 != 0) {
      final cached = prefs.getString('friends_of_friends_${widget.uid}');
      if (cached != null) {
        try {
          final List decoded = json.decode(cached);
          List<Map<String, String>> cachedList =
              decoded.map<Map<String, String>>((e) {
                return {
                  'id': e['id'] ?? '',
                  'uid': e['uid'] ?? '',
                  'name': e['name'] ?? '',
                  'iconUrl': e['iconUrl'] ?? '',
                };
              }).toList();
          // 既に friendList にあるユーザーを除外
          final friendUIDSet = _friendList.map((e) => e['uid']).toSet();
          cachedList =
              cachedList
                  .where((user) => !friendUIDSet.contains(user['uid']))
                  .toList();
          debugPrint('Using cached friends_of_friends: $cachedList');
          setState(() {
            _friendsOfFriends = cachedList;
          });
          return;
        } catch (_) {
          debugPrint('friends_of_friends キャッシュ読み込みエラー');
        }
      }
    }

    debugPrint('Firebaseから友達の友達リストを取得します');
    List<Map<String, String>> temp = [];
    for (var friend in _friendList) {
      debugPrint('Firestoreにアクセス: ユーザー ${friend['uid']} の friendList を取得中...');
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(friend['uid'])
              .collection('friendList')
              .get();

      debugPrint(
        '友達 ${friend['uid']} の friendList から取得したドキュメント数: ${snapshot.docs.length}',
      );
      for (var doc in snapshot.docs) {
        final data = doc.data();
        temp.add({
          'id': data['id'] ?? '',
          'uid': doc.id,
          'name': data['name'] ?? '',
          'iconUrl': data['iconUrl'] ?? '',
        });
      }
    }
    // 重複削除
    final unique = <String, Map<String, String>>{};
    for (var item in temp) {
      unique[item['uid'] ?? ''] = item;
    }
    List<Map<String, String>> result = unique.values.toList();
    // friendListにあるユーザーを除外
    final friendUIDSet = _friendList.map((e) => e['uid']).toSet();
    result =
        result.where((user) => !friendUIDSet.contains(user['uid'])).toList();

    await prefs.setString(
      'friends_of_friends_${widget.uid}',
      json.encode(result),
    );
    debugPrint('Firebaseから取得した友達の友達リストをキャッシュに保存: $result');

    setState(() {
      _friendsOfFriends = result;
    });
  }

  // 4) 近くの友達リスト（キャッシュあり＋3回に1回はFirebase更新）
  Future<void> _fetchNearbyFriends() async {
    final prefs = await SharedPreferences.getInstance();
    int fetchCount = prefs.getInt('nearbyFriends_fetchCount') ?? 0;
    fetchCount++;
    await prefs.setInt('nearbyFriends_fetchCount', fetchCount);

    if (fetchCount != 3) {
      final cached = prefs.getString('nearby_friends_${widget.uid}');
      if (cached != null) {
        try {
          final List decoded = json.decode(cached);
          List<Map<String, String>> cachedList =
              decoded.map<Map<String, String>>((e) {
                return {
                  'id': e['id'] ?? '',
                  'uid': e['uid'] ?? '',
                  'name': e['name'] ?? 'namae',
                  'iconUrl': e['iconUrl'] ?? '',
                };
              }).toList();
          final friendUIDSet = _friendList.map((e) => e['uid']).toSet();
          cachedList =
              cachedList
                  .where((user) => !friendUIDSet.contains(user['uid']))
                  .toList();
          debugPrint('Using cached nearby_friends: $cachedList');
          setState(() {
            _nearbyFriends = cachedList;
          });
          fetchCount = 0;
          // return;
        } catch (_) {
          debugPrint('nearby_friends キャッシュ読み込みエラー');
        }
      }
    }

    debugPrint('Firebaseから近くの友達リストを取得します');
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .get();
    if (!userDoc.exists) return;
    final userData = userDoc.data()!;
    final myStatus = userData['city'] ?? '';

    List<Map<String, String>> nearList =
        (await FirebaseFirestore.instance
                .collection('users')
                .where('city', isEqualTo: myStatus)
                .get())
            .docs
            .map<Map<String, String>>((doc) {
              final data = doc.data();
              return {
                'id': data['id'] ?? '',
                'uid': doc.id,
                'name': data['name'] ?? '',
                'iconUrl': data['iconUrl'] ?? '',
              };
            })
            .where((item) => item['uid'] != widget.uid)
            .toList();
    final friendUIDSet = _friendList.map((e) => e['uid']).toSet();
    nearList =
        nearList.where((user) => !friendUIDSet.contains(user['uid'])).toList();

    await prefs.setString(
      'nearby_friends_${widget.uid}',
      json.encode(nearList),
    );
    debugPrint('Firebaseから取得した近くの友達リストをキャッシュに保存: $nearList');

    setState(() {
      _nearbyFriends = nearList;
    });
  }

  // 5) プロフィール取得（requestspossible フィールド含む）
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
        _requestsPossible = data['requestspossible'] ?? 1;
      });
      debugPrint('取得したプロフィール: $_profile');
    }
  }

  // 6) sendlist および playrequests サブコレクションの処理
  Future<void> _fetchSendList() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .get();
    if (doc.exists) {
      final data = doc.data()!;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final lastDateStr = data['lastPlayRequestDate'];
      if (lastDateStr == null || lastDateStr != todayStr) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .update({'sendlist': []});
        setState(() {
          _sendList = [];
        });
        final playRequestsSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.uid)
                .collection('playrequests')
                .get();
        for (var doc in playRequestsSnapshot.docs) {
          await doc.reference.delete();
        }
      } else {
        final list = data['sendlist'];
        if (list != null && list is List) {
          setState(() {
            _sendList = List<String>.from(list);
          });
        }
      }
    }
  }

  // 7) playrequests のリスナー設定（有効期限チェック付き）
  void _setupPlayRequestsListener() {
    _playRequestsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('playrequests')
        .snapshots()
        .listen((snapshot) {
          List<String> newIncoming = [];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final senderUid = data['uid'];
            final Timestamp? timestamp = data['date'] as Timestamp?;
            if (timestamp != null) {
              DateTime requestDate = timestamp.toDate();
              if (!isSameDay(requestDate, DateTime.now())) continue;
              if (senderUid != null) {
                newIncoming.add(senderUid);
              }
            }
          }
          setState(() {
            _incomingPlayRequests = newIncoming;
          });
        });
  }

  // ホーム側で送信後に sendlist を更新するコールバック
  Future<void> _refreshSendList() async {
    await _fetchSendList();
  }

  // 友達追加後のコールバック
  Future<void> _handleFriendAdded() async {
    // Firestoreから最新のfriendListを取得して更新
    await _fetchFriendList();
    // PlayRequestPage など、friendListを参照するページも再描画される
  }

  // BottomNavigationBar のタップ処理
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // build
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      FriendAddPage(
        uid: widget.uid,
        followRequests: _followRequests,
        friendList: _friendList,
        friendsOfFriends: _friendsOfFriends,
        nearbyFriends: _nearbyFriends,
        onFriendAdded: _handleFriendAdded, // 友達追加後の更新を通知
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
      FriendPage(uid: widget.uid, friendList: _friendList),
      PlayRequestPage(
        uid: widget.uid,
        friendList: _friendList,
        requestsPossible: _requestsPossible,
        incomingPlayRequests: _incomingPlayRequests,
        sendList: _sendList,
        lastPlayRequestDate: _lastPlayRequestDate,
        onRefreshSendList: _refreshSendList,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: '友達追加'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '友達チャット'),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_arrow),
            label: '遊びリクエスト',
          ),
        ],
      ),
    );
  }
}
