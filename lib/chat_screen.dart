import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String myUid;
  final String friendUid;
  final String friendName; // 表示用相手の名前

  const ChatScreen({
    Key? key,
    required this.myUid,
    required this.friendUid,
    required this.friendName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// チャットルームID生成: 小さいUID_大きいUID など
String makeChatRoomId(String uid1, String uid2) {
  if (uid1.compareTo(uid2) < 0) {
    return '${uid1}_$uid2';
  } else {
    return '${uid2}_$uid1';
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  late String chatRoomId;

  @override
  void initState() {
    super.initState();
    chatRoomId = makeChatRoomId(widget.myUid, widget.friendUid);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // メッセージ送信
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messageData = {
      'text': text,
      'senderUid': widget.myUid,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // 1) メッセージの追加
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    // 2) 互いの friendlist に lastMessageTime を更新
    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.myUid)
        .collection('friendlist')
        .doc(widget.friendUid)
        .update({'lastMessageTime': now})
        .catchError((e) {
          // もし friendlist ドキュメントがない場合は set() で作ってもよい
        });
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.friendUid)
        .collection('friendlist')
        .doc(widget.myUid)
        .update({'lastMessageTime': now})
        .catchError((e) {});

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.friendName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // メッセージ表示部分
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatRoomId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'メッセージがありません',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true, // 最新メッセージを上に
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msgData = docs[index].data() as Map<String, dynamic>;
                    final text = msgData['text'] ?? '';
                    final senderUid = msgData['senderUid'] ?? '';
                    final isMe = senderUid == widget.myUid;
                    return _buildMessageBubble(text, isMe);
                  },
                );
              },
            ),
          ),
          // 入力欄
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'メッセージを入力',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // メッセージ一つ分の吹き出し
  Widget _buildMessageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueGrey : Colors.grey[700],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
