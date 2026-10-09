import 'package:flutter/material.dart';

import '../../../app/home_screen.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/network/farm_api.dart';
import '../../../core/network/mock_config.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/widgets/mushroom_glyph.dart';
import '../../public_growth/public_growth_screen.dart';

// (auth_controller.dart được rút gọn thành logic ngay trong State bên dưới)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Đóng màn đăng nhập. Nếu đây là route gốc (không có gì để pop) thì mở Home.
  void _finish(bool loggedIn) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(loggedIn);
    } else {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _handleLogin() async {
    if (_loading) return; // chống nhấn đôi
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text; // mật khẩu không trim
    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên đăng nhập và mật khẩu.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // POST /login -> lưu token -> GET /auth/me -> chỉ vào khu nội bộ khi hồ sơ hợp lệ.
      await FarmApi.instance.login(user, pass);
      if (!mounted) return;
      _finish(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => _finish(false),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(height: 12),
                      const Center(child: MushroomGlyph(size: 92)),
                      const SizedBox(height: 18),
                      Text(
                        tr(context, vi: 'Chào mừng trở lại', en: 'Welcome back'),
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          context,
                          vi: 'Đăng nhập để quản lý cơ sở, giống nấm và lô nuôi trồng.',
                          en: 'Sign in to manage facilities, strains and cultivation batches.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: MockConfig.notifier,
                    builder: (context, on, _) {
                      if (!on) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? AppColors.warning.withValues(alpha: 0.14)
                              : AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.science_outlined, size: 18, color: AppColors.warning),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tr(context,
                                      vi: 'Chế độ dữ liệu mẫu: chưa cần backend. Bấm để điền sẵn tài khoản:',
                                      en: 'Demo data mode: no backend needed. Tap to fill an account:'),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              for (final a in MockConfig.demoAccounts)
                                ActionChip(
                                  label: Text('${a.$1} · ${a.$3}'),
                                  onPressed: () => setState(() {
                                    _userCtrl.text = a.$1;
                                    _passCtrl.text = a.$2;
                                    _error = null;
                                  }),
                                ),
                            ]),
                          ],
                        ),
                      );
                    },
                  ),
                  CustomTextField(
                    label: tr(context, vi: 'Tài khoản', en: 'Username'),
                    controller: _userCtrl,
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: tr(context, vi: 'Mật khẩu', en: 'Password'),
                    controller: _passCtrl,
                    obscure: _obscure,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  CustomButton(
                    label: tr(context, vi: 'Đăng nhập', en: 'Sign in'),
                    onPressed: _handleLogin,
                    loading: _loading,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          tr(context, vi: 'hoặc', en: 'or'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: Text(tr(context, vi: 'Tra cứu tiến trình lô', en: 'Look up a batch')),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const PublicGrowthScreen())),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.center_focus_strong_rounded),
                    label: Text(
                      tr(
                        context,
                        vi: 'Dùng Nhận diện & Từ điển, không cần đăng nhập',
                        en: 'Use Recognition & Catalog without signing in',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: () => _finish(false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
