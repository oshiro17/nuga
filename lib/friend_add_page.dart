import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendAddPage extends StatefulWidget {
  final String uid;
  final List<Map<String, String>> followRequests;
  final List<Map<String, String>> friendList;
  final List<Map<String, String>> friendsOfFriends;
  final List<Map<String, String>> nearbyFriends;

  const FriendAddPage({
    Key? key,
    required this.uid,
    required this.followRequests,
    required this.friendList,
    required this.friendsOfFriends,
    required this.nearbyFriends,
  }) : super(key: key);

  @override
  State<FriendAddPage> createState() => _FriendAddPageState();
}

class _FriendAddPageState extends State<FriendAddPage> {
  late List<Map<String, String>> _followRequests;
  late List<Map<String, String>> _friendList;
  late List<Map<String, String>> _friendsOfFriends;
  late List<Map<String, String>> _nearbyFriends;

  // 検索用の状態
  String _searchQuery = "";
  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // 受け取ったリストを State 内にコピー
    _followRequests = List.from(widget.followRequests);
    _friendList = List.from(widget.friendList);
    _friendsOfFriends = List.from(widget.friendsOfFriends);
    _nearbyFriends = List.from(widget.nearbyFriends);
  }

  Future<void> _acceptFollowRequest(Map<String, String> user) async {
    final userUid = user['uid'];
    if (userUid == null) return;
    try {
      // 例: フォローリクエスト一覧から削除 (Firestore)
      // 友達リストに追加 (Firestore)
      // ...詳しい処理は省略

      // ローカルの followRequests から削除
      setState(() {
        _followRequests.removeWhere((element) => element['uid'] == userUid);
      });
    } catch (e) {
      debugPrint('フォローリクエスト追加エラー: $e');
    }
  }

  /// おすすめの「追加」ボタン
  Future<void> _addFriend(Map<String, String> user) async {
    final userUid = user['uid'];
    if (userUid == null) return;
    try {
      // Firestore の friendList に追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('friendList')
          .doc(userUid)
          .set({
            'uid': user['uid'],
            'name': user['name'] ?? '',
            'iconUrl': user['iconUrl'] ?? '',
          });

      // ローカルの _friendsOfFriends または _nearbyFriends から削除
      setState(() {
        _friendsOfFriends.removeWhere((element) => element['uid'] == userUid);
        _nearbyFriends.removeWhere((element) => element['uid'] == userUid);
      });
      // SharedPreferences からも削除
      final prefs = await SharedPreferences.getInstance();

      // friends_of_friends のキャッシュ更新
      final cachedFoF = prefs.getString('friends_of_friends_${widget.uid}');
      if (cachedFoF != null) {
        try {
          final List<dynamic> decoded = json.decode(cachedFoF);
          decoded.removeWhere((element) => element['uid'] == userUid);
          await prefs.setString(
            'friends_of_friends_${widget.uid}',
            json.encode(decoded),
          );
        } catch (e) {
          debugPrint('friends_of_friends キャッシュ更新エラー: $e');
        }
      }

      // nearby_friends のキャッシュ更新
      final cachedNearby = prefs.getString('nearby_friends_${widget.uid}');
      if (cachedNearby != null) {
        try {
          final List<dynamic> decoded = json.decode(cachedNearby);
          decoded.removeWhere((element) => element['uid'] == userUid);
          await prefs.setString(
            'nearby_friends_${widget.uid}',
            json.encode(decoded),
          );
        } catch (e) {
          debugPrint('nearby_friends キャッシュ更新エラー: $e');
        }
      }
    } catch (e) {
      debugPrint('友達追加エラー: $e');
    }
  }

  // Firestore の users コレクションから、電話番号またはidで検索する処理
  Future<void> _performSearch() async {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    List<Map<String, String>> results = [];

    // try {
    //   // ドキュメントIDで検索
    //   final doc =
    //       await FirebaseFirestore.instance.collection('users').doc(query).get();
    //   if (doc.exists) {
    //     final data = doc.data() as Map<String, dynamic>;
    //     results.add({
    //       'uid': doc.id,
    //       'name': data['name'] ?? '',
    //       'iconUrl': data['iconUrl'] ?? '',
    //     });
    //   }
    // }
    //
    try {
      // 'phone' フィールドで検索
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('id', isEqualTo: query)
              .get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        Map<String, String> userMap = {
          'uid': doc.id,
          'name': data['name'] ?? '',
          'iconUrl': data['iconUrl'] ?? '',
        };
        // 重複排除
        if (!results.any((element) => element['uid'] == doc.id)) {
          results.add(userMap);
        }
      }
    } catch (e) {
      debugPrint('ID検索エラー: $e');
    }

    try {
      // 'phone' フィールドで検索
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('phoneNumber', isEqualTo: query)
              .get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        Map<String, String> userMap = {
          'uid': doc.id,
          'name': data['name'] ?? '',
          'iconUrl': data['iconUrl'] ?? '',
        };
        // 重複排除
        if (!results.any((element) => element['uid'] == doc.id)) {
          results.add(userMap);
        }
      }
    } catch (e) {
      debugPrint('電話番号検索エラー: $e');
    }

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // friendList にいるユーザーの uid を排除したリストを作って表示する
    final friendUidSet = _friendList.map((f) => f['uid']).toSet();
    // 友達の友達 + 近くの友達をまとめたリスト
    final recommendedList =
        [
          ..._friendsOfFriends,
          ..._nearbyFriends,
        ].where((u) => !friendUidSet.contains(u['uid'])).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('友達追加')),
      body: Column(
        children: [
          // 1) 検索フィールド（電話番号またはIDで検索）
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: '電話番号またはIDで検索',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _performSearch,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          // 2) 検索結果がある場合は表示
          if (_searchResults.isNotEmpty)
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '検索結果',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                (user['iconUrl'] ?? '').isNotEmpty
                                    ? NetworkImage(user['iconUrl']!)
                                    : null,
                            child:
                                (user['iconUrl'] ?? '').isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                          ),
                          title: Text(user['name'] ?? 'No Name'),
                          trailing: ElevatedButton(
                            onPressed: () => _addFriend(user),
                            child: const Text('追加'),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                ],
              ),
            ),
          // 3) フォローリクエスト一覧（固定高さ）
          if (_followRequests.isNotEmpty)
            SizedBox(
              height: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'フォローリクエスト',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _followRequests.length,
                      itemBuilder: (context, index) {
                        final user = _followRequests[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                (user['iconUrl'] ?? '').isNotEmpty
                                    ? NetworkImage(user['iconUrl']!)
                                    : null,
                            child:
                                (user['iconUrl'] ?? '').isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                          ),
                          title: Text(user['name'] ?? 'No Name'),
                          trailing: ElevatedButton(
                            onPressed: () => _acceptFollowRequest(user),
                            child: const Text('追加'),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                ],
              ),
            ),
          // 4) 友達の友達リストの表示
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '友達の友達',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _friendsOfFriends.length,
                    itemBuilder: (context, index) {
                      final user = _friendsOfFriends[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              (user['iconUrl'] ?? '').isNotEmpty
                                  ? NetworkImage(user['iconUrl']!)
                                  : null,
                          child:
                              (user['iconUrl'] ?? '').isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                        ),
                        title: Text(user['name'] ?? 'No Name'),
                        trailing: ElevatedButton(
                          onPressed: () => _addFriend(user),
                          child: const Text('追加'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 5) 近くの友達リストの表示
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '近くの友達',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _nearbyFriends.length,
                    itemBuilder: (context, index) {
                      final user = _nearbyFriends[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              (user['iconUrl'] ?? '').isNotEmpty
                                  ? NetworkImage(user['iconUrl']!)
                                  : null,
                          child:
                              (user['iconUrl'] ?? '').isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                        ),
                        title: Text(user['name'] ?? 'No Name'),
                        trailing: ElevatedButton(
                          onPressed: () => _addFriend(user),
                          child: const Text('追加'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
