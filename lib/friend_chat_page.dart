// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'chat_screen.dart';

// class FriendChatPage extends StatefulWidget {
//   final String uid; // ログイン中のユーザーUID
//   const FriendChatPage({
//     Key? key,
//     required this.uid,
//     required List<DocumentSnapshot<Object?>> friendDocs,
//   }) : super(key: key);

//   @override
//   State<FriendChatPage> createState() => _FriendChatPageState();
// }

// class _FriendChatPageState extends State<FriendChatPage> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'NUGA',
//           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
//         ),
//       ),
//       backgroundColor: Colors.black,
//       body: StreamBuilder<QuerySnapshot>(
//         stream:
//             FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(widget.uid)
//                 .collection('friendlist')
//                 .orderBy('lastMessageTime', descending: true)
//                 .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(
//               child: CircularProgressIndicator(color: Colors.white),
//             );
//           }
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(
//               child: Text('友達がいません', style: TextStyle(color: Colors.white)),
//             );
//           }
//           final friendDocs = snapshot.data!.docs;

//           return ListView.builder(
//             itemCount: friendDocs.length,
//             itemBuilder: (context, index) {
//               final friendUid = friendDocs[index].id;
//               return FutureBuilder<DocumentSnapshot>(
//                 future:
//                     FirebaseFirestore.instance
//                         .collection('users')
//                         .doc(friendUid)
//                         .get(),
//                 builder: (context, userSnapshot) {
//                   if (!userSnapshot.hasData) {
//                     return const ListTile(
//                       title: Text(
//                         '読み込み中...',
//                         style: TextStyle(color: Colors.white),
//                       ),
//                     );
//                   }
//                   if (!userSnapshot.data!.exists) {
//                     return const ListTile(
//                       title: Text(
//                         'ユーザー情報なし',
//                         style: TextStyle(color: Colors.white),
//                       ),
//                     );
//                   }
//                   final friendData =
//                       userSnapshot.data!.data() as Map<String, dynamic>;
//                   final friendName = friendData['name'] ?? 'No Name';
//                   final friendId = friendData['id'] ?? '';
//                   return ListTile(
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder:
//                               (_) => ChatScreen(
//                                 myUid: widget.uid,
//                                 friendUid: friendUid,
//                                 friendName: friendName,
//                               ),
//                         ),
//                       );
//                     },
//                     leading:
//                         (friendData['iconUrl'] != null &&
//                                 friendData['iconUrl'].toString().startsWith(
//                                   'http',
//                                 ))
//                             ? CircleAvatar(
//                               backgroundColor: Colors.white,
//                               // ClipOvalで丸くトリミングしてから画像を表示
//                               child: ClipOval(
//                                 child: Image.network(
//                                   friendData['iconUrl'],
//                                   fit: BoxFit.cover,
//                                   width: 40,
//                                   height: 40,
//                                   // エラーが発生した場合のウィジェット
//                                   errorBuilder: (context, error, stackTrace) {
//                                     return Icon(
//                                       Icons.error,
//                                       color: Colors.black,
//                                     );
//                                   },
//                                 ),
//                               ),
//                             )
//                             : const CircleAvatar(
//                               backgroundColor: Colors.grey,
//                               child: Icon(Icons.person, color: Colors.black),
//                             ),
//                     title: Text(
//                       friendName,
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                     subtitle: Text(
//                       friendId,
//                       style: const TextStyle(color: Colors.white70),
//                     ),
//                   );

//                   // return ListTile(
//                   //   onTap: () {
//                   //     // チャット画面へ遷移
//                   //     Navigator.push(
//                   //       context,
//                   //       MaterialPageRoute(
//                   //         builder:
//                   //             (_) => ChatScreen(
//                   //               myUid: widget.uid,
//                   //               friendUid: friendUid,
//                   //               friendName: friendName,
//                   //             ),
//                   //       ),
//                   //     );
//                   //   },
//                   //   leading: const CircleAvatar(
//                   //     backgroundColor: Colors.white,
//                   //     child: Icon(Icons.person, color: Colors.black),
//                   //   ),
//                   //   title: Text(
//                   //     friendName,
//                   //     style: const TextStyle(color: Colors.white),
//                   //   ),
//                   //   subtitle: Text(
//                   //     friendId,
//                   //     style: const TextStyle(color: Colors.white70),
//                   //   ),
//                   // );
//                 },
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
