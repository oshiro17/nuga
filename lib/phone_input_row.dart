import 'package:flutter/material.dart';

class PhoneInputRow extends StatefulWidget {
  const PhoneInputRow({Key? key}) : super(key: key);

  @override
  _PhoneInputRowState createState() => _PhoneInputRowState();
}

class _PhoneInputRowState extends State<PhoneInputRow> {
  // サンプルとして国番号候補をリスト化
  final List<String> _countryCodes = ['+81', '+1', '+86', '+49', '+61'];

  // 選択された国番号
  String _selectedCountryCode = '+81';

  // 電話番号の入力コントローラ（国番号以外の部分）
  final TextEditingController _phoneNumberController = TextEditingController();

  // 完全な電話番号を取得するgetter
  String get fullPhoneNumber =>
      _selectedCountryCode + _phoneNumberController.text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 国番号のドロップダウン
            DropdownButton<String>(
              value: _selectedCountryCode,
              onChanged: (String? newValue) {
                setState(() {
                  if (newValue != null) {
                    _selectedCountryCode = newValue;
                  }
                });
              },
              items:
                  _countryCodes.map<DropdownMenuItem<String>>((String code) {
                    return DropdownMenuItem<String>(
                      value: code,
                      child: Text(code),
                    );
                  }).toList(),
            ),
            const SizedBox(width: 8),
            // 電話番号入力フィールド（国番号以外）
            Expanded(
              child: TextField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: '電話番号',
                  hintText: '例) 8098527749',
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 入力内容を表示する例
        Text('入力された完全な電話番号: $fullPhoneNumber'),
      ],
    );
  }
}
