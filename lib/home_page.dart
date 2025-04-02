// home_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ringring/profile_page.dart';
import 'package:ringring/friend_add_page.dart';
import 'package:ringring/friend_page.dart';
import 'package:ringring/play_request_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final String uid;
  const HomePage({Key? key, required this.uid}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // UI 用
  int _selectedIndex = 0;
  bool _isLoading = true;

  // その他のデータ（友達リスト等）
  List<Map<String, String>> _followRequests = [];
  List<Map<String, String>> _friendList = [];
  List<Map<String, String>> _friendsOfFriends = [];
  List<Map<String, String>> _nearbyFriends = [];
  List<DocumentSnapshot> _friendDocs = [];
  int _requestsPossible = 1;
  List<String> _sendList = [];
  List<String> _incomingPlayRequests = [];
  DateTime? _lastPlayRequestDate;
  StreamSubscription? _playRequestsSubscription;

  // 取得したプロフィール情報
  String _profileIconUrl = '';
  String _profileName = '';
  String _profileStatus = '';

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

  // 全データをまとめて取得する
  Future<void> _loadData() async {
    try {
      await _fetchProfile(); // プロフィール情報を先に取得
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

  // Firestore からユーザーのプロフィール情報を取得
  Future<void> _fetchProfile() async {
    try {
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        setState(() {
          _profileIconUrl = data?['iconUrl'] ?? '';
          _profileName = data?['name'] ?? '';
          _profileStatus = data?['status'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('プロフィール取得エラー: $e');
    }
  }

  // ※ 以下、他のデータ取得処理（_fetchFollowRequests, _fetchFriendList, …）は既存の実装と同様です

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

  Future<void> _fetchFriendList() async {
    final friendListSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('friendList')
            .get();

    final friendUIDs = friendListSnapshot.docs.map((doc) => doc.id).toList();

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

    setState(() {
      _friendList = friends;
    });
    debugPrint('Firebaseから取得したフレンドリスト: $friends');
  }

  Future<void> _fetchFriendsOfFriends() async {
    // 省略（既存の実装）
  }

  Future<void> _fetchNearbyFriends() async {
    // 省略（既存の実装）
  }

  Future<void> _fetchSendList() async {
    // 省略（既存の実装）
  }

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

  // 以下、その他のコールバック処理（_refreshSendList, _handleFriendAdded など）もそのまま

  Future<void> _refreshSendList() async {
    await _fetchSendList();
  }

  Future<void> _handleFriendAdded() async {
    await _fetchFriendList();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 日付が同じかどうかのヘルパー関数
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

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
        onFriendAdded: _handleFriendAdded,
      ),
      // 取得済みのプロフィール情報を ProfilePage に渡す
      ProfilePage(
        uid: widget.uid,
        iconUrl: _profileIconUrl,
        name: _profileName,
        status: _profileStatus,
        onProfileUpdated: () async {
          // 編集後、再度プロフィール情報を更新
          await _fetchProfile();
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
