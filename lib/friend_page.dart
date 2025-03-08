// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'chat_screen.dart';

// class FriendPage extends StatelessWidget {
//   final String uid; // ログイン中のユーザーUID
//   final List<DocumentSnapshot> friendDocs; // HomePageでキャッシュした友達情報

//   const FriendPage({Key? key, required this.uid, required this.friendDocs})
//     : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     // 友達情報がない場合の表示
//     if (friendDocs.isEmpty) {
//       return Scaffold(
//         appBar: AppBar(
//           title: const Text('友達チャット', style: TextStyle(color: Colors.white)),
//           backgroundColor: Colors.black,
//         ),
//         backgroundColor: Colors.black,
//         body: const Center(
//           child: Text('友達がいません', style: TextStyle(color: Colors.white)),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('友達チャット', style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.black,
//       ),
//       backgroundColor: Colors.black,
//       body: ListView.builder(
//         itemCount: friendDocs.length,
//         itemBuilder: (context, index) {
//           final friendData = friendDocs[index].data() as Map<String, dynamic>;
//           final friendUid = friendDocs[index].id;
//           final friendName = friendData['name'] ?? 'No Name';
//           // final friendId = friendData['id'] ?? '';

//           return ListTile(
//             onTap: () {
//               // チャット画面へ遷移
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder:
//                       (_) => ChatScreen(
//                         myUid: uid,
//                         friendUid: friendUid,
//                         friendName: friendName,
//                       ),
//                 ),
//               );
//             },
//             leading: const CircleAvatar(
//               backgroundColor: Colors.white,
//               child: Icon(Icons.person, color: Colors.black),
//             ),
//             title: Text(
//               friendName,
//               style: const TextStyle(color: Colors.white),
//             ),
//             // subtitle: Text(
//             //   friendId,
//             //   style: const TextStyle(color: Colors.white70),
//             // ),
//           );
//         },
//       ),
//     );
//   }
// }
