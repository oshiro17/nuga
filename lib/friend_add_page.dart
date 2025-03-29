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
  final VoidCallback? onFriendAdded; // 友達追加後のコールバック

  const FriendAddPage({
    Key? key,
    required this.uid,
    required this.followRequests,
    required this.friendList,
    required this.friendsOfFriends,
    required this.nearbyFriends,
    this.onFriendAdded,
  }) : super(key: key);

  @override
  State<FriendAddPage> createState() => _FriendAddPageState();
}

class _FriendAddPageState extends State<FriendAddPage> {
  late List<Map<String, String>> _followRequests;
  // friendList は表示に使わないので省略
  late List<Map<String, String>> _friendsOfFriends;
  late List<Map<String, String>> _nearbyFriends;

  // 検索用の状態
  String _searchQuery = "";
  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _followRequests = List.from(widget.followRequests);
    _friendsOfFriends = List.from(widget.friendsOfFriends);
    _nearbyFriends = List.from(widget.nearbyFriends);
  }

  @override
  void didUpdateWidget(covariant FriendAddPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.followRequests != widget.followRequests) {
      setState(() {
        _followRequests = List.from(widget.followRequests);
      });
    }
    if (oldWidget.friendsOfFriends != widget.friendsOfFriends) {
      setState(() {
        _friendsOfFriends = List.from(widget.friendsOfFriends);
      });
    }
    if (oldWidget.nearbyFriends != widget.nearbyFriends) {
      setState(() {
        _nearbyFriends = List.from(widget.nearbyFriends);
      });
    }
  }

  Future<void> _acceptFollowRequest(Map<String, String> user) async {
    final userUid = user['uid'];
    if (userUid == null) return;
    try {
      setState(() {
        _followRequests.removeWhere((element) => element['uid'] == userUid);
      });
    } catch (e) {
      debugPrint('フォローリクエスト追加エラー: $e');
    }
  }

  Future<void> _addFriend(Map<String, String> user) async {
    final userUid = user['uid'];
    if (userUid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('friendList')
          .doc(userUid)
          .set({'uid': user['uid']});

      setState(() {
        _friendsOfFriends.removeWhere((element) => element['uid'] == userUid);
        _nearbyFriends.removeWhere((element) => element['uid'] == userUid);
      });

      final prefs = await SharedPreferences.getInstance();
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
      // 友達追加成功後、親に通知して friendList の更新を促す
      widget.onFriendAdded?.call();
    } catch (e) {
      debugPrint('友達追加エラー: $e');
    }
  }

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

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('id', isEqualTo: query)
              .get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        Map<String, String> userMap = {
          'id': query,
          'uid': doc.id,
          'name': data['name'] ?? '',
          'iconUrl': data['iconUrl'] ?? '',
        };
        if (!results.any((element) => element['uid'] == doc.id)) {
          results.add(userMap);
        }
      }
    } catch (e) {
      debugPrint('ID検索エラー: $e');
    }

    try {
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
    return Scaffold(
      appBar: AppBar(title: const Text('友達追加')),
      body: Column(
        children: [
          // 検索フィールド
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: '電話番号またはIDで検索',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: _performSearch),
          // 検索結果表示
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
                          title: Row(
                            children: [
                              Text(user['id'] ?? 'No ID'),
                              const SizedBox(width: 8),
                              Text(
                                user['name'] ?? 'No Name',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
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
          // フォローリクエスト表示
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
          // 友達の友達リスト表示
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
                        title: Text(user['id'] ?? 'No Name'),
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
          // 近くの友達リスト表示
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
                        title: Row(
                          children: [
                            Text(user['id'] ?? 'No ID'),
                            const SizedBox(width: 8),
                            Text(
                              user['name'] ?? 'No Name',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
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
