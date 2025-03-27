import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ringring/home_page.dart'; // ※必要に応じて利用

// ヘルパー：日付が同じかどうかチェック
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

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
  // 選択中の友達 UID リスト（未送信状態での選択用）
  List<String> _selectedFriends = [];
  bool _isSending = false;
  String _searchQuery = "";

  // マッチ済みかどうかを判定（送信済みかつ受信済みならマッチ）
  bool isMatched(String friendUid) {
    return widget.sendList.contains(friendUid) &&
        widget.incomingPlayRequests.contains(friendUid);
  }

  // １日に既に送信済みかどうかのチェック
  bool get hasSentToday {
    if (widget.lastPlayRequestDate == null) return false;
    return isSameDay(widget.lastPlayRequestDate!, DateTime.now());
  }

  // チェックボックス（選択／解除）の切り替え
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

  // プレイリクエスト送信処理（１日１回制御＋当日の日付を記録）
  Future<void> _sendPlayRequests() async {
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
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    // 選択した各友達に対してリクエスト送信（playrequests サブコレクションへ追加）
    for (var friendUid in _selectedFriends) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(friendUid)
          .collection('playrequests')
          .doc(widget.uid)
          .set({'uid': widget.uid, 'date': now});
      // 自分の sendlist にも追加（Firestore の arrayUnion）
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

    setState(() {
      _selectedFriends.clear();
      _isSending = false;
    });

    await widget.onRefreshSendList();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('プレイリクエストを送信しました')));
  }

  @override
  Widget build(BuildContext context) {
    // 各状態用に送信済み・マッチ済みの友達リストを抽出
    final sentFriends =
        widget.friendList.where((friend) {
          return widget.sendList.contains(friend['uid']);
        }).toList();

    final matchedFriends =
        widget.friendList.where((friend) {
          final uid = friend['uid'] ?? '';
          return widget.sendList.contains(uid) &&
              widget.incomingPlayRequests.contains(uid);
        }).toList();

    // 友達検索の結果（友達一覧から _searchQuery にマッチするもの）
    final filteredFriendList =
        widget.friendList.where((friend) {
          final name = friend['name'] ?? '';
          return name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

    // 未送信状態か（送信済みなら hasSentRequest = true）
    bool hasSentRequest = widget.sendList.isNotEmpty;

    // 未送信状態：友達選択画面
    if (!hasSentRequest) {
      return Scaffold(
        appBar: AppBar(title: const Text("NUGA")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "今日、遊びたい人を${widget.requestsPossible}人選択しよう！",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.friendList.length,
                  itemBuilder: (context, index) {
                    final friend = widget.friendList[index];
                    final friendUid = friend['uid'] ?? '';
                    final isSelected = _selectedFriends.contains(friendUid);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: ListTile(
                        leading:
                            friend['iconUrl'] != ''
                                ? CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    friend['iconUrl']!,
                                  ),
                                )
                                : const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(friend['name'] ?? ''),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (value) => _toggleSelection(friendUid),
                        ),
                        onTap: () => _toggleSelection(friendUid),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendPlayRequests,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child:
                      _isSending
                          ? const CircularProgressIndicator()
                          : Text(
                            "プレイリクエスト送信 (${_selectedFriends.length}/${widget.requestsPossible})",
                          ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 送信済み状態（既にリクエスト送信済みの場合）
    return Scaffold(
      appBar: AppBar(title: const Text("NUGA")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // マッチ状態：マッチがあれば上部にマッチ通知セクションを表示
              if (matchedFriends.isNotEmpty) ...[
                Text(
                  "${matchedFriends.first['name']}さんとマッチしました！",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        matchedFriends.first['iconUrl'] != ''
                            ? CircleAvatar(
                              backgroundImage: NetworkImage(
                                matchedFriends.first['iconUrl']!,
                              ),
                              radius: 30,
                            )
                            : const CircleAvatar(
                              child: Icon(Icons.person),
                              radius: 30,
                            ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            matchedFriends.first['name'] ?? '',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            // メッセージ画面への遷移処理（実装例）
                          },
                          child: const Text("メッセージ画面へ！"),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // 「あなたが今日遊びたい人」セクション
              const Text(
                "あなたが今日遊びたい人",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: sentFriends.length,
                  itemBuilder: (context, index) {
                    final friend = sentFriends[index];
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          friend['iconUrl'] != ''
                              ? CircleAvatar(
                                backgroundImage: NetworkImage(
                                  friend['iconUrl']!,
                                ),
                                radius: 30,
                              )
                              : const CircleAvatar(
                                child: Icon(Icons.person),
                                radius: 30,
                              ),
                          const SizedBox(height: 8),
                          Text(
                            friend['name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // 友達検索欄
              TextField(
                decoration: InputDecoration(
                  hintText: "友達を名前で検索",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              // 検索結果／友達一覧
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredFriendList.length,
                itemBuilder: (context, index) {
                  final friend = filteredFriendList[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ListTile(
                      leading:
                          friend['iconUrl'] != ''
                              ? CircleAvatar(
                                backgroundImage: NetworkImage(
                                  friend['iconUrl']!,
                                ),
                              )
                              : const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(friend['name'] ?? ''),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
