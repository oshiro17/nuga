import 'package:flutter/material.dart';
import 'package:ringring/chat_screen.dart';

class FriendPage extends StatelessWidget {
  final String uid; // ログイン中のユーザーUID
  final List<Map<String, String>> friendList; // HomePageで保持している友達リスト

  const FriendPage({Key? key, required this.uid, required this.friendList})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 友達情報がない場合の表示
    if (friendList.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('友達チャット', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black,
        ),
        backgroundColor: Colors.black,
        body: const Center(
          child: Text('友達がいません', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('友達チャット', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: ListView.builder(
        itemCount: friendList.length,
        itemBuilder: (context, index) {
          final friend = friendList[index];
          final friendUid = friend['uid'] ?? '';
          final friendName = friend['name'] ?? 'No Name';

          return ListTile(
            onTap: () {
              // ここでチャット画面へ遷移する処理を記述（例）
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => ChatScreen(
                        myUid: uid,
                        friendUid: friendUid,
                        friendName: friendName,
                      ),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundImage:
                  (friend['iconUrl'] ?? '').isNotEmpty
                      ? NetworkImage(friend['iconUrl']!)
                      : null,
              child:
                  (friend['iconUrl'] ?? '').isEmpty
                      ? const Icon(Icons.person)
                      : null,
            ),
            title: Text(
              friendName,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}
