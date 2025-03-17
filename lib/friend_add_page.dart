import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// フォローリクエストの「追加」ボタン
  Future<void> _acceptFollowRequest(Map<String, String> user) async {
    final userUid = user['uid'];
    if (userUid == null) return;

    try {
      // 1) follow_request_list から削除
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('follow_request_list')
          .doc(userUid)
          .delete();

      // 2) friend_list に追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('friend_list')
          .doc(userUid)
          .set({'name': user['name'] ?? '', 'iconUrl': user['iconUrl'] ?? ''});

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
      // Firestore の friend_list に追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('friend_list')
          .doc(userUid)
          .set({'name': user['name'] ?? '', 'iconUrl': user['iconUrl'] ?? ''});

      // ローカルの _friendsOfFriends または _nearbyFriends から削除
      // 同じ uid がいれば削除
      setState(() {
        _friendsOfFriends.removeWhere((element) => element['uid'] == userUid);
        _nearbyFriends.removeWhere((element) => element['uid'] == userUid);
      });
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1) フォローリクエスト一覧
            const SizedBox(height: 8),
            const Text(
              'フォローリクエスト',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            ..._followRequests.map((user) {
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
            }).toList(),
            const Divider(),

            // 2) おすすめ一覧 (友達の友達 + 近くの友達)
            const SizedBox(height: 8),
            const Text(
              'おすすめ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            ...recommendedList.map((user) {
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
            }).toList(),
          ],
        ),
      ),
    );
  }
}
