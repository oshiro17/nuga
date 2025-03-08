// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class FriendAddPage extends StatefulWidget {
//   final String uid;
//   const FriendAddPage({Key? key, required this.uid}) : super(key: key);

//   @override
//   State<FriendAddPage> createState() => _FriendAddPageState();
// }

// class _FriendAddPageState extends State<FriendAddPage> {
//   final TextEditingController _searchController = TextEditingController();

//   // 検索バーが空の場合 => 近くのおすすめ & 友達の友達
//   // 検索バーが入力されている場合 => ID検索結果
//   Future<Map<String, List<Map<String, dynamic>>>>? _userListsFuture;

//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(_onSearchChanged);
//     _loadUserLists();
//   }

//   @override
//   void dispose() {
//     _searchController.removeListener(_onSearchChanged);
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _onSearchChanged() {
//     _loadUserLists();
//   }

//   // 検索バーが空欄なら「近くのおすすめ + 友達の友達」を取得
//   // 入力があれば ID 検索
//   void _loadUserLists() {
//     final query = _searchController.text.trim();
//     if (query.isEmpty) {
//       setState(() {
//         _userListsFuture = _loadAllLists();
//       });
//     } else {
//       setState(() {
//         _userListsFuture = _searchUsersById(query).then((searchResult) {
//           return {
//             'nearUsers': <Map<String, dynamic>>[],
//             'friendsOfFriends': <Map<String, dynamic>>[],
//             'searchResult': searchResult,
//           };
//         });
//       });
//     }
//   }

//   /// 近くのユーザー & 友達の友達リストを同時に取得
//   /// 戻り値: {'nearUsers': [...], 'friendsOfFriends': [...]}
//   Future<Map<String, List<Map<String, dynamic>>>> _loadAllLists() async {
//     try {
//       // 自分のドキュメントを取得して市町村を確認
//       DocumentSnapshot myDoc =
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(widget.uid)
//               .get();
//       if (!myDoc.exists) {
//         // 自分の情報がなければ空を返す
//         return {
//           'nearUsers': <Map<String, dynamic>>[],
//           'friendsOfFriends': <Map<String, dynamic>>[],
//         };
//       }

//       final myData = myDoc.data() as Map<String, dynamic>;
//       final myMunicipality = myData['municipality'] ?? '';

//       // ① 自分の friendlist を取得
//       QuerySnapshot myFriendsSnapshot =
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(widget.uid)
//               .collection('friendlist')
//               .get();
//       Set<String> myFriendUids =
//           myFriendsSnapshot.docs.map((doc) => doc.id).toSet();

//       // -------------------------
//       // 1) 近くのおすすめユーザー（同じ市町村）
//       // -------------------------
//       // 自分を除外し、かつ friendlist に含まれるユーザーを除外
//       // Municipality の一致するユーザーをクエリ
//       QuerySnapshot nearSnapshot =
//           await FirebaseFirestore.instance
//               .collection('users')
//               .where('municipality', isEqualTo: myMunicipality)
//               .limit(100) // 一旦最大100件
//               .get();

//       List<Map<String, dynamic>> nearUsers = [];
//       for (var doc in nearSnapshot.docs) {
//         if (doc.id == widget.uid) continue; // 自分は除外
//         if (myFriendUids.contains(doc.id)) continue; // 既に友達のユーザーは除外

//         nearUsers.add(doc.data() as Map<String, dynamic>);
//       }
//       // シャッフルして 30 件に絞る
//       nearUsers.shuffle();
//       if (nearUsers.length > 30) {
//         nearUsers = nearUsers.sublist(0, 30);
//       }

//       // -------------------------
//       // 2) 友達の友達リスト
//       // -------------------------
//       // friendUidList を取得してシャッフル
//       List<String> friendUidsList = myFriendUids.toList();
//       friendUidsList.shuffle();

//       Set<String> recommendedUids = {};
//       for (String friendUid in friendUidsList) {
//         if (recommendedUids.length >= 30) break;
//         QuerySnapshot friendFriendSnapshot =
//             await FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(friendUid)
//                 .collection('friendlist')
//                 .get();
//         for (var doc in friendFriendSnapshot.docs) {
//           recommendedUids.add(doc.id);
//         }
//       }

//       // 自分 & 自分の friendlist を除外
//       recommendedUids.removeAll(myFriendUids);
//       recommendedUids.remove(widget.uid);

//       // シャッフルして最大 30 件
//       List<String> recommendedUidList = recommendedUids.toList();
//       recommendedUidList.shuffle();
//       if (recommendedUidList.length > 30) {
//         recommendedUidList = recommendedUidList.sublist(0, 30);
//       }

//       List<Map<String, dynamic>> friendsOfFriends = [];
//       for (String uid in recommendedUidList) {
//         DocumentSnapshot doc =
//             await FirebaseFirestore.instance.collection('users').doc(uid).get();
//         if (doc.exists) {
//           friendsOfFriends.add(doc.data() as Map<String, dynamic>);
//         }
//       }

//       return {'nearUsers': nearUsers, 'friendsOfFriends': friendsOfFriends};
//     } catch (e) {
//       debugPrint('おすすめユーザー取得エラー: $e');
//       return {
//         'nearUsers': <Map<String, dynamic>>[],
//         'friendsOfFriends': <Map<String, dynamic>>[],
//       };
//     }
//   }

//   /// ID検索
//   Future<List<Map<String, dynamic>>> _searchUsersById(String idQuery) async {
//     try {
//       QuerySnapshot snapshot =
//           await FirebaseFirestore.instance
//               .collection('users')
//               .where('id', isEqualTo: idQuery)
//               .get();
//       return snapshot.docs
//           .map((doc) => doc.data() as Map<String, dynamic>)
//           .toList();
//     } catch (e) {
//       debugPrint('ID検索エラー: $e');
//       return [];
//     }
//   }

//   /// 友達追加
//   Future<void> _addFriend(String friendUid) async {
//     final currentUser = FirebaseAuth.instance.currentUser;
//     if (currentUser != null) {
//       try {
//         await FirebaseFirestore.instance
//             .collection('users')
//             .doc(currentUser.uid)
//             .collection('friendlist')
//             .doc(friendUid)
//             .set({
//               'friendUid': friendUid,
//               'addedAt': FieldValue.serverTimestamp(),
//             });
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text('Friend added!')));
//         _loadUserLists();
//       } catch (e) {
//         debugPrint('友達追加エラー: $e');
//       }
//     }
//   }

//   /// ユーザーアイテム表示
//   Widget _buildUserItem(Map<String, dynamic> userData) {
//     String displayName = userData['name'] ?? 'No Name';
//     String iconUrl = userData['iconUrl'] ?? '';
//     String userUid = userData['uid'] ?? '';
//     return ListTile(
//       leading:
//           iconUrl.startsWith('http')
//               ? CircleAvatar(
//                 backgroundImage: NetworkImage(iconUrl),
//                 backgroundColor: Colors.white,
//               )
//               : const CircleAvatar(
//                 backgroundColor: Colors.grey,
//                 child: Icon(Icons.person, color: Colors.black),
//               ),
//       title: Text(displayName, style: const TextStyle(color: Colors.white)),
//       subtitle: Text(
//         userData['id'] ?? '',
//         style: const TextStyle(color: Colors.white70),
//       ),
//       trailing: ElevatedButton(
//         onPressed: () => _addFriend(userUid),
//         style: ElevatedButton.styleFrom(
//           foregroundColor: Colors.black,
//           backgroundColor: Colors.white,
//         ),
//         child: const Text('追加'),
//       ),
//     );
//   }

//   /// 「近くのおすすめユーザー」「友達の友達リスト」表示
//   Widget _buildAllListsSection(Map<String, List<Map<String, dynamic>>> data) {
//     final nearUsers = data['nearUsers'] ?? [];
//     final friendsOfFriends = data['friendsOfFriends'] ?? [];

//     return SingleChildScrollView(
//       child: Column(
//         children: [
//           // 近くのおすすめユーザー
//           const Padding(
//             padding: EdgeInsets.all(8.0),
//             child: Text(
//               '近くのおすすめユーザー',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           if (nearUsers.isNotEmpty)
//             //   const Text(
//             //     '同じ市町村のユーザーは見つかりません',
//             //     style: TextStyle(color: Colors.white),
//             //   )
//             // else
//             ...nearUsers.map((u) => _buildUserItem(u)).toList(),

//           const SizedBox(height: 20),
//           // 友達の友達リスト
//           const Padding(
//             padding: EdgeInsets.all(8.0),
//             child: Text(
//               '友達の友達リスト',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           if (friendsOfFriends.isNotEmpty)
//             ...friendsOfFriends.map((u) => _buildUserItem(u)).toList(),
//           const SizedBox(height: 20),
//         ],
//       ),
//     );
//   }

//   /// ID 検索結果表示
//   Widget _buildSearchResultSection(List<Map<String, dynamic>> searchList) {
//     if (searchList.isEmpty) {
//       return const Center(
//         child: Text('該当するユーザーが見つかりません', style: TextStyle(color: Colors.white)),
//       );
//     }
//     return ListView.builder(
//       itemCount: searchList.length,
//       itemBuilder: (context, index) {
//         return _buildUserItem(searchList[index]);
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('友達を追加', style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.black,
//       ),
//       backgroundColor: Colors.black,
//       body: Column(
//         children: [
//           // 検索バー
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: TextField(
//               controller: _searchController,
//               style: const TextStyle(color: Colors.white),
//               decoration: InputDecoration(
//                 hintText: 'IDで検索...',
//                 hintStyle: const TextStyle(color: Colors.white54),
//                 prefixIcon: const Icon(Icons.search, color: Colors.white),
//                 filled: true,
//                 fillColor: Colors.grey[800],
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8.0),
//                   borderSide: BorderSide.none,
//                 ),
//               ),
//             ),
//           ),
//           Expanded(
//             child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
//               future: _userListsFuture,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(
//                     child: CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     ),
//                   );
//                 }
//                 if (snapshot.hasError) {
//                   return Center(
//                     child: Text(
//                       'エラーが発生しました: ${snapshot.error}',
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                   );
//                 }
//                 if (!snapshot.hasData) {
//                   return const Center(
//                     child: Text(
//                       'データがありません',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   );
//                 }

//                 final data = snapshot.data!;
//                 // 検索結果があるかどうか確認
//                 if (data.containsKey('searchResult')) {
//                   // ID検索モード
//                   final results = data['searchResult']!;
//                   return _buildSearchResultSection(results);
//                 } else {
//                   // 近くのおすすめ & 友達の友達
//                   return _buildAllListsSection(data);
//                 }
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
