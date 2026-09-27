import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Botanical AI Press',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// ----------------------------------------------------
// 1. ログイン画面（デモ用）
// ----------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController(text: 'demo@example.com');
  final _passwordController = TextEditingController(text: 'password');

  void _login() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const FlowerApp()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_florist,
                      size: 56,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Botanical AI Press',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '社内プロトタイプ検証システム',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'パスワード',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'ログイン',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 2. メイン機能画面（AI変換機能）
// ----------------------------------------------------
class FlowerApp extends StatefulWidget {
  const FlowerApp({super.key});

  @override
  State<FlowerApp> createState() => _FlowerAppState();
}

class _FlowerAppState extends State<FlowerApp> {
  // ★ 後ほどVercelにデプロイしたあとのURLへ書き換えます
  final String vercelApiUrl = 'https://h002-pressed-flower-app.vercel.app/api/generate';

  Uint8List? _selectedImageBytes;
  String? _resultImageUrl;
  bool _isLoading = false;
  String _statusText = '';

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _resultImageUrl = null;
        _statusText = '';
      });
    }
  }

  Future<void> _generatePressedFlower() async {
    if (_selectedImageBytes == null) return;

    setState(() {
      _isLoading = true;
      _statusText = '中間サーバー（Vercel）へ処理をリクエスト中...';
    });

    try {
      String base64Image = base64Encode(_selectedImageBytes!);

      final response = await http.post(
        Uri.parse(vercelApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'imageBase64': base64Image,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        String getUrl = data['urls']['get'];
        _pollResult(getUrl);
      } else {
        String errorMsg = data['error'] ?? data['detail'] ?? response.body;
        setState(() {
          _isLoading = false;
          _statusText = 'エラー (${response.statusCode}): $errorMsg';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = '通信エラー: $e';
      });
    }
  }

  Future<void> _pollResult(String getUrl) async {
    setState(() {
      _statusText = '押し花アートを生成中... (数秒お待ちください)';
    });

    while (true) {
      await Future.delayed(const Duration(seconds: 2));

      final response = await http.get(Uri.parse(getUrl));
      final data = jsonDecode(response.body);
      String status = data['status'];

      if (status == 'succeeded') {
        setState(() {
          _isLoading = false;
          _resultImageUrl = data['output'] is List ? data['output'][0] : data['output'];
          _statusText = '生成が完了しました！';
        });
        break;
      } else if (status == 'failed' || status == 'canceled') {
        setState(() {
          _isLoading = false;
          _statusText = '生成処理に失敗しました: ${data['error'] ?? status}';
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F6),
      appBar: AppBar(
        title: const Text('Botanical AI Press'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('写真を選択'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('カメラで撮影'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF388E3C),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_selectedImageBytes != null) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('元画像:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_selectedImageBytes!, height: 180, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generatePressedFlower,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('押し花風アートに変換'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        ),
                      ),
                    ],
                    if (_isLoading) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(_statusText, style: const TextStyle(color: Colors.grey)),
                    ],
                    if (_resultImageUrl != null) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(_resultImageUrl!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}