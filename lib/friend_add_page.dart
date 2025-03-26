import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    // 受け取ったリストを State 内にコピー（参照をそのまま使う場合は注意）
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
      // 同じ uid がいれば削除
      setState(() {
        _friendsOfFriends.removeWhere((element) => element['uid'] == userUid);
        _nearbyFriends.removeWhere((element) => element['uid'] == userUid);
      });
      // SharedPreferences からも削除
      final prefs = await SharedPreferences.getInstance();

      // friends_of_friends
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

      // nearby_friends
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

  @override
  Widget build(BuildContext context) {
    // friendList にいるユーザーの uid を排除したリストを作って表示する
    final friendUidSet = _friendList.map((f) => f['uid']).toSet();

    // 友達の友達 + 近くの友達をまとめたリスト
    final recommendedList =
        [..._friendsOfFriends, ..._nearbyFriends]
            // すでに friendList にいる人は除外
            .where((u) => !friendUidSet.contains(u['uid']))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('友達追加')),
      body: Column(
        children: [
          // 1) フォローリクエスト一覧（固定高さ）
          if (_followRequests.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'フォローリクエスト',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(
              height: 200,
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
          // 2) 友達の友達リスト
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '友達の友達',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
          // 3) 近くの友達リスト
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '近くの友達',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
