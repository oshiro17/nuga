import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ringring/home_page.dart';
import 'package:ringring/setting_id_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PhoneAuthExampleApp());
}

class PhoneAuthExampleApp extends StatelessWidget {
  const PhoneAuthExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone Auth Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 入力を管理するコントローラ
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  // 選択された国コード（デフォルトは日本）
  String _selectedCountryCode = '+81';

  // 認証用フォーマット済み電話番号（例: +818098527749）と生の電話番号（例: 08098527749）
  String? _formattedPhoneNumber;
  String? _rawPhoneNumber;

  // 国コードと国旗のリスト（例）
  final List<Map<String, String>> _countryCodes = [
    {"code": "+81", "flag": "🇯🇵"},
    {"code": "+1", "flag": "🇺🇸"},
    {"code": "+44", "flag": "🇬🇧"},
  ];

  String? _verificationId;
  String _statusMessage = '';

  // ユーザーがまだ登録されていなければ、usersコレクションにUIDと電話番号を登録する
  Future<void> _registerUserIfNotExists(String uid, String phoneNumber) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      // uid と電話番号（生の電話番号）を保存
      await docRef.set({'uid': uid, 'phoneNumber': phoneNumber});
    } else {
      // 既に存在する場合も、電話番号フィールドを更新（必要なら）
      await docRef.set({'phoneNumber': phoneNumber}, SetOptions(merge: true));
    }
  }

  // 電話番号認証の実行
  Future<void> _verifyPhoneNumber() async {
    // ユーザーが入力した電話番号をそのまま取得（例："08098527749"）
    String rawInput = _phoneNumberController.text.trim();
    _rawPhoneNumber = rawInput; // そのまま保存用に保持

    // 認証用には、先頭の"0"を除去して国コードを付与（例: "+81" + "8098527749" → "+818098527749"）
    String phoneNumberInput = rawInput;
    if (phoneNumberInput.startsWith('0')) {
      phoneNumberInput = phoneNumberInput.substring(1);
    }
    _formattedPhoneNumber = _selectedCountryCode + phoneNumberInput;

    setState(() {
      _statusMessage = '認証コードを送信しています...';
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _formattedPhoneNumber!,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // 自動認証成功時
          await _auth.signInWithCredential(credential);
          if (_auth.currentUser != null && _rawPhoneNumber != null) {
            // 登録時は生の電話番号を使用
            await _registerUserIfNotExists(
              _auth.currentUser!.uid,
              _rawPhoneNumber!,
            );
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (context) => SettingIdPage(uid: _auth.currentUser!.uid),
              ),
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _statusMessage = '認証失敗: ${e.message}';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _statusMessage = 'コード送信完了';
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
            _statusMessage = '自動入力タイムアウト';
          });
        },
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'エラーが発生しました: $e';
      });
    }
  }

  // SMSコードでサインイン
  Future<void> _signInWithSmsCode() async {
    if (_verificationId == null) {
      setState(() {
        _statusMessage = '認証IDが存在しません。先に「コード送信」してください。';
      });
      return;
    }

    final smsCode = _smsCodeController.text.trim();
    if (smsCode.isEmpty) {
      setState(() {
        _statusMessage = 'SMSコードを入力してください。';
      });
      return;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await _auth.signInWithCredential(credential);
      if (_auth.currentUser != null && _rawPhoneNumber != null) {
        // 登録時は生の電話番号を使用
        await _registerUserIfNotExists(
          _auth.currentUser!.uid,
          _rawPhoneNumber!,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SettingIdPage(uid: _auth.currentUser!.uid),
          ),
        );
      } else {
        setState(() {
          _statusMessage = 'ログインに失敗しました。';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _statusMessage = 'ログイン失敗: ${e.message}';
      });
    }
  }

  // 現在ログイン中のユーザー情報を確認
  Future<void> _checkCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _statusMessage = 'ログイン中: ${user.uid}';
      });
    } else {
      setState(() {
        _statusMessage = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NUGA',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              'お帰りなさい！',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
            ),
            const SizedBox(height: 40),
            // 電話番号入力フィールド（国コード選択付き）
            TextField(
              controller: _phoneNumberController,
              decoration: InputDecoration(
                labelText: '電話番号',
                prefix: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountryCode,
                    items:
                        _countryCodes.map((country) {
                          return DropdownMenuItem<String>(
                            value: country['code'],
                            child: Text(
                              "${country['flag']} ${country['code']}",
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCountryCode = value!;
                      });
                    },
                  ),
                ),
                hintText: '例: 090xxxxxxxx',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _verifyPhoneNumber,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                '認証コードを送信',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(_statusMessage, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 32),
            TextField(
              controller: _smsCodeController,
              decoration: const InputDecoration(labelText: 'SMSコード（6桁など）'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signInWithSmsCode,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                '認証',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
