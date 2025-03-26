// -------------------------------
// 新規追加: PlayRequestPage の実装例
// -------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PlayRequestPage extends StatefulWidget {
  final String uid;
  final List<Map<String, String>> friendList;
  final int requestsPossible;
  final List<String> incomingPlayRequests;
  final List<String> sendList;
  final Future<void> Function() onRefreshSendList;

  const PlayRequestPage({
    Key? key,
    required this.uid,
    required this.friendList,
    required this.requestsPossible,
    required this.incomingPlayRequests,
    required this.sendList,
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

  // プレイリクエストの送信処理
  Future<void> _sendPlayRequests() async {
    if (_selectedFriends.isEmpty) return;
    setState(() {
      _isSending = true;
    });

    final now = Timestamp.now();

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

    // 送信後、選択状態をクリア
    setState(() {
      _selectedFriends.clear();
      _isSending = false;
    });

    // HomePage 側の sendlist を更新
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
              onPressed: _isSending ? null : _sendPlayRequests,
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
