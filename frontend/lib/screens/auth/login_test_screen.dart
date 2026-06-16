import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../services/storage_service.dart';
import '../../config/api_config.dart';
import '../../config/env_config.dart';

/// Temporary dev-only screen to verify backend ↔ Flutter integration end-to-end.
///
/// Tests: OTP send → devOTP verify → token stored → authenticated socket.
/// Remove this file and its route in main.dart before release.
class LoginTestScreen extends StatefulWidget {
  const LoginTestScreen({super.key});

  @override
  State<LoginTestScreen> createState() => _LoginTestScreenState();
}

class _LoginTestScreenState extends State<LoginTestScreen> {
  final _phoneCtrl = TextEditingController(text: '+919876543210');
  final _otpCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _log = 'Ready — enter phone and tap Send OTP\n';
  bool _otpSent    = false;
  bool _loading    = false;

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _append(String msg) {
    setState(() => _log += '$msg\n');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setLoading(bool v) => setState(() => _loading = v);

  // ── OTP flow ────────────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    _setLoading(true);
    _append('→ Sending OTP to ${_phoneCtrl.text} ...');
    _append('  baseUrl: ${ApiConfig.baseUrl}');
    try {
      await AuthService().sendOTP(_phoneCtrl.text);
      setState(() => _otpSent = true);
      _append('✅ OTP sent! (dev mode: check backend console for devOTP)');
    } catch (e) {
      _append('❌ Send OTP failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _verifyOtp() async {
    _setLoading(true);
    _append('→ Verifying OTP: ${_otpCtrl.text} ...');
    try {
      final user = await AuthService().verifyOTP(_phoneCtrl.text, _otpCtrl.text);
      _append('✅ Login successful!');
      _append('   ID: ${user.id} | Role: ${user.role}');
      _append('   Name: ${user.name ?? "(not set)"}');

      final token = await StorageService().getAccessToken();
      if (token != null && token.length > 20) {
        _append('   Token (first 30): ${token.substring(0, 30)}...');
      }
    } catch (e) {
      _append('❌ Verify OTP failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ── Socket test ─────────────────────────────────────────────────────────────

  Future<void> _testSocket() async {
    _append('→ Connecting socket to ${ApiConfig.socketUrl} (path /ws) ...');
    try {
      await SocketService().connect();
      await Future.delayed(const Duration(seconds: 3));
      if (SocketService().isConnected) {
        _append('✅ Socket connected!');
        SocketService().emit('ping', null);
        _append('   ping emitted — check backend logs');
      } else {
        _append('❌ Socket NOT connected after 3s — check path /ws and token');
      }
    } catch (e) {
      _append('❌ Socket error: $e');
    }
  }

  // ── Authenticated API test ─────────────────────────────────────────────────

  Future<void> _testAuthApi() async {
    _append('→ Calling GET /auth/me ...');
    try {
      final user = await AuthService().getMe();
      if (user != null) {
        _append('✅ /auth/me: ${user.id} | ${user.role}');
      } else {
        _append('⚠️  /auth/me: no user (token expired or not saved)');
      }
    } catch (e) {
      _append('❌ /auth/me failed: $e');
    }
  }

  Future<void> _testHealthCheck() async {
    _append('→ Calling GET ${EnvConfig.backendRootUrl}/health ...');
    try {
      final ok = await AuthService().healthCheck();
      if (ok) {
        _append('✅ /health reachable');
      } else {
        _append('❌ /health returned unexpected response');
      }
    } catch (e) {
      _append('❌ /health failed: $e');
    }
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  Future<void> _clearStorage() async {
    await StorageService().clear();
    SocketService().disconnect();
    setState(() {
      _log = 'Storage cleared. Ready for fresh test.\n';
      _otpSent = false;
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Backend Integration Test'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear storage & log',
            onPressed: _clearStorage,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
          // Config banner
          Container(
            width: double.infinity,
            color: Colors.orange.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Backend: ${ApiConfig.baseUrl}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),

          // Phone + OTP input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (E.164 or 10-digit)',
                    hintText: '+919876543210',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _sendOtp,
                        icon: const Icon(Icons.send),
                        label: const Text('Send OTP'),
                      ),
                    ),
                  ],
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'OTP (from devOTP in backend console)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_open),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _verifyOtp,
                          icon: const Icon(Icons.verified_user),
                          label: const Text('Verify & Login'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),

                // Post-login tests
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _testSocket,
                        icon: const Icon(Icons.electrical_services),
                        label: const Text('Test Socket'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _testAuthApi,
                        icon: const Icon(Icons.person_pin),
                        label: const Text('GET /auth/me'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _testHealthCheck,
                        icon: const Icon(Icons.health_and_safety),
                        label: const Text('Health Check'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Console log panel
          Expanded(
            child: Container(
              color: const Color(0xFF1E1E1E),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                child: Text(
                  _log,
                  style: const TextStyle(
                    color: Color(0xFF00FF00),
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),

          if (_loading)
            const LinearProgressIndicator(
              backgroundColor: Colors.black,
              color: Colors.deepOrange,
            ),
        ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
