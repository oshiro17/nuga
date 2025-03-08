// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:ringring/profile_page_model.dart';

// class LocationEditPage extends StatefulWidget {
//   final String uid;
//   final ProfilePageModel? profile;

//   const LocationEditPage({Key? key, required this.uid, required this.profile})
//     : super(key: key);

//   @override
//   State<LocationEditPage> createState() => _LocationEditPageState();
// }

// class _LocationEditPageState extends State<LocationEditPage> {
//   // 選択中の都道府県と市町村
//   String? _selectedPrefecture;
//   String? _selectedCity;

//   // 都道府県ごとの市町村リストのサンプルデータ
//   final Map<String, List<String>> prefectureCities = {
//     'Tokyo': ['Chiyoda', 'Shinjuku', 'Shibuya', 'Taito'],
//     'Osaka': ['Kita', 'Naniwa', 'Tennoji'],
//     'Hokkaido': ['Sapporo', 'Hakodate', 'Asahikawa'],
//     'Aichi': ['Nagoya', 'Toyota', 'Okazaki'],
//   };

//   @override
//   void initState() {
//     super.initState();
//     // 既存の位置情報があれば初期値に設定
//     // _selectedPrefecture = widget.profile?.prefecture;
//     _selectedCity = widget.profile?.municipality;
//   }

//   Future<void> _saveLocation() async {
//     Map<String, dynamic> locationData = {
//       // 'prefecture': _selectedPrefecture,
//       'municipality': _selectedCity,
//     };

//     try {
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(widget.uid)
//           .set(locationData, SetOptions(merge: true));
//       // 更新したデータを返して前の画面で反映
//       Navigator.pop(context, locationData);
//     } catch (e) {
//       debugPrint('位置情報保存エラー: $e');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('位置情報の保存に失敗しました。')));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('位置情報を編集'),
//         backgroundColor: Colors.black,
//       ),
//       backgroundColor: Colors.black,
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // 都道府県選択
//             DropdownButtonFormField<String>(
//               value: _selectedPrefecture,
//               dropdownColor: Colors.grey[800],
//               style: const TextStyle(color: Colors.white),
//               decoration: InputDecoration(
//                 labelText: '都道府県',
//                 labelStyle: const TextStyle(color: Colors.white),
//                 filled: true,
//                 fillColor: Colors.grey[800],
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8.0),
//                   borderSide: BorderSide.none,
//                 ),
//               ),
//               items:
//                   prefectureCities.keys.map((prefecture) {
//                     return DropdownMenuItem<String>(
//                       value: prefecture,
//                       child: Text(prefecture),
//                     );
//                   }).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedPrefecture = value;
//                   _selectedCity = null; // 都道府県変更時は市町村をリセット
//                 });
//               },
//             ),
//             const SizedBox(height: 16),
//             // 市町村選択（都道府県が選ばれている場合のみ）
//             DropdownButtonFormField<String>(
//               value: _selectedCity,
//               dropdownColor: Colors.grey[800],
//               style: const TextStyle(color: Colors.white),
//               decoration: InputDecoration(
//                 labelText: '市町村',
//                 labelStyle: const TextStyle(color: Colors.white),
//                 filled: true,
//                 fillColor: Colors.grey[800],
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8.0),
//                   borderSide: BorderSide.none,
//                 ),
//               ),
//               items:
//                   _selectedPrefecture != null
//                       ? prefectureCities[_selectedPrefecture!]!.map((city) {
//                         return DropdownMenuItem<String>(
//                           value: city,
//                           child: Text(city),
//                         );
//                       }).toList()
//                       : [],
//               onChanged: (value) {
//                 setState(() {
//                   _selectedCity = value;
//                 });
//               },
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _saveLocation,
//               style: ElevatedButton.styleFrom(
//                 foregroundColor: Colors.black,
//                 backgroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8.0),
//                 ),
//               ),
//               child: const Text(
//                 '保存',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
