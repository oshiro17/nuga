import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  int _requestsPossible = 1; // requestspossible フィールド（null の場合は 1）
  List<String> _sendList = []; // 自分が送信したリクエスト先の友達 UID のリスト
  List<String> _incomingPlayRequests = []; // 自分が受信した playrequests の送信者 UID のリスト
  DateTime? _lastPlayRequestDate; // 最後にリクエスト送信した日（"yyyy-MM-dd"）
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

  // 2) フレンドリスト（キャッシュあり）
  Future<void> _fetchFriendList() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('friendList_${widget.uid}');
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
        debugPrint('キャッシュされたフレンドリスト: $_friendList');
        setState(() {});
      } catch (_) {
        debugPrint('フレンドリストのキャッシュ読み込みエラー');
      }
    } else {
      debugPrint('フレンドリストのキャッシュは存在しません');
    }

    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('friendList')
            .get();

    _friendDocs = snapshot.docs;

    final friends =
        snapshot.docs.map<Map<String, String>>((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'uid': doc.id,
            'name': data['name'] ?? '',
            'iconUrl': data['iconUrl'] ?? '',
          };
        }).toList();

    await prefs.setString('friendList_${widget.uid}', json.encode(friends));
    debugPrint('Firebaseから取得したフレンドリストをキャッシュに保存: $friends');

    setState(() {
      _friendList = friends;
    });
  }

  // 3) 友達の友達リスト（キャッシュあり）
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
        debugPrint('キャッシュされた友達の友達リスト: $_friendsOfFriends');
        setState(() {});
      } catch (_) {
        debugPrint('友達の友達リストのキャッシュ読み込みエラー');
      }
    } else {
      debugPrint('友達の友達リストのキャッシュは存在しません');
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
        debugPrint('取得したドキュメント: id=${doc.id}, data=$data');
        temp.add({
          'uid': doc.id,
          'name': data['name'] ?? '',
          'iconUrl': data['iconUrl'] ?? '',
        });
      }
    }
    // 重複削除（キーは uid）
    final unique = <String, Map<String, String>>{};
    for (var item in temp) {
      unique[item['uid'] ?? ''] = item;
    }
    final result = unique.values.toList();

    await prefs.setString(
      'friends_of_friends_${widget.uid}',
      json.encode(result),
    );
    debugPrint('Firebaseから取得した友達の友達リストをキャッシュに保存: $result');

    setState(() {
      _friendsOfFriends = result;
    });
  }

  // 4) 近くの友達リスト（キャッシュあり）
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
        return;
      } catch (_) {
        debugPrint('近くの友達リストのキャッシュ読み込みエラー');
      }
    } else {
      debugPrint('近くの友達リストのキャッシュは存在しません');
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
            .where((item) => item['uid'] != widget.uid)
            .toList();

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

  // 6) 自分が送信した play request のリスト (sendlist) と最後の送信日を取得
  Future<void> _fetchSendList() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .get();
    if (doc.exists) {
      final data = doc.data()!;
      final list = data['sendlist'];
      if (list != null && list is List) {
        setState(() {
          _sendList = List<String>.from(list);
        });
      }
      // lastPlayRequestDate は "yyyy-MM-dd" 形式で保存
      final lastDateStr = data['lastPlayRequestDate'];
      if (lastDateStr != null && lastDateStr is String) {
        final parsed = DateTime.tryParse(lastDateStr);
        if (parsed != null) {
          setState(() {
            _lastPlayRequestDate = parsed;
          });
        }
      }
    }
  }

  // 7) 自分の playrequests サブコレクションのリスナー設定（受信したリクエスト：有効期限チェック付き）
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
              // 本日と異なるリクエストは無効として除外
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

  // ホーム側で送信後に sendlist を更新するためのコールバック
  Future<void> _refreshSendList() async {
    await _fetchSendList();
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

    // 各ページの設定（FriendAddPage, ProfilePage, FriendPage, PlayRequestPage）
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
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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

// -------------------------------
// 新規追加: PlayRequestPage の実装例（有効期限チェック＆１日１回制御付き）
// -------------------------------
class PlayRequestPage extends StatefulWidget {
  final String uid;
  final List<Map<String, String>> friendList;
  final int requestsPossible;
  final List<String> incomingPlayRequests;
  final List<String> sendList;
  final DateTime? lastPlayRequestDate; // 最後に送信した日
  final Future<void> Function() onRefreshSendList;

  const PlayRequestPage({
    Key? key,
    required this.uid,
    required this.friendList,
    required this.requestsPossible,
    required this.incomingPlayRequests,
    required this.sendList,
    required this.lastPlayRequestDate,
    required this.onRefreshSendList,
  }) : super(key: key);

  @override
  State<PlayRequestPage> createState() => _PlayRequestPageState();
}

class _PlayRequestPageState extends State<PlayRequestPage> {
  // 選択した友達の UID リスト
  List<String> _selectedFriends = [];
  bool _isSending = false;

  // マッチ済みかどうかを判定する関数
  bool isMatched(String friendUid) {
    return widget.sendList.contains(friendUid) &&
        widget.incomingPlayRequests.contains(friendUid);
  }

  // １日に既に送信済みかどうかをチェックする関数
  bool get hasSentToday {
    if (widget.lastPlayRequestDate == null) return false;
    return isSameDay(widget.lastPlayRequestDate!, DateTime.now());
  }

  // 友達の選択／解除
  void _toggleSelection(String friendUid) {
    setState(() {
      if (_selectedFriends.contains(friendUid)) {
        _selectedFriends.remove(friendUid);
      } else {
        if (_selectedFriends.length < widget.requestsPossible) {
          _selectedFriends.add(friendUid);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('本日のリクエスト可能数は ${widget.requestsPossible} 件です。'),
            ),
          );
        }
      }
    });
  }

  // プレイリクエストの送信処理（１日１回制御＆有効期限として本日の日付を記録）
  Future<void> _sendPlayRequests() async {
    // 既に本日送信済みの場合は処理しない
    if (hasSentToday) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本日は既にプレイリクエストを送信済みです。')));
      return;
    }

    if (_selectedFriends.isEmpty) return;
    setState(() {
      _isSending = true;
    });

    final now = Timestamp.now();
    // 本日の日付を "yyyy-MM-dd" 形式で保存
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    // 選択した各友達へ playrequests サブコレクションに自分のリクエストを追加
    for (var friendUid in _selectedFriends) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(friendUid)
          .collection('playrequests')
          .doc(widget.uid) // 自分の UID をドキュメントIDにする
          .set({
            'uid': widget.uid,
            'date': now,
            // 必要に応じて追加のユーザー情報を保存可能
          });
      // 自分の sendlist にも追加（Firestore の arrayUnion を利用）
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({
            'sendlist': FieldValue.arrayUnion([friendUid]),
          });
    }

    // １日に一度しか送信できないよう、lastPlayRequestDate を更新
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update(
      {'lastPlayRequestDate': todayStr},
    );

    // 送信後、選択状態をクリア
    setState(() {
      _selectedFriends.clear();
      _isSending = false;
    });

    // HomePage 側の sendlist 等の更新
    await widget.onRefreshSendList();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('プレイリクエストを送信しました')));
  }

  // マッチ済みの友達タップ時のダイアログ表示
  void _onMatchedFriendTap(String friendUid) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('マッチしました！'),
            content: const Text('この友達とチャットを開始しますか？'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // チャット画面への遷移処理をここに追加可能
                },
                child: const Text('はい'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('いいえ'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('遊びリクエスト'),
        actions: [
          // 右上にリクエスト可能数をバッジ表示
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: Text(widget.requestsPossible.toString()),
              backgroundColor: Colors.redAccent,
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.friendList.length,
              itemBuilder: (context, index) {
                final friend = widget.friendList[index];
                final friendUid = friend['uid'] ?? '';
                final isSelected = _selectedFriends.contains(friendUid);
                final matched = isMatched(friendUid);

                return ListTile(
                  leading:
                      friend['iconUrl'] != ''
                          ? CircleAvatar(
                            backgroundImage: NetworkImage(friend['iconUrl']!),
                          )
                          : const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(friend['name'] ?? ''),
                  // マッチしている友達は背景色を変更
                  tileColor: matched ? Colors.greenAccent : null,
                  trailing:
                      isSelected
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : null,
                  onTap: () {
                    if (matched) {
                      // 既にマッチ済みの場合はダイアログ表示
                      _onMatchedFriendTap(friendUid);
                    } else {
                      _toggleSelection(friendUid);
                    }
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: hasSentToday || _isSending ? null : _sendPlayRequests,
              child:
                  _isSending
                      ? const CircularProgressIndicator()
                      : Text(
                        'プレイリクエスト送信 (${_selectedFriends.length}/${widget.requestsPossible})',
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
