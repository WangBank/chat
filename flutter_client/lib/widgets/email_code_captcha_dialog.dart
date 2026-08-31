import 'package:flutter/material.dart';

import '../services/api_service.dart';

Future<EmailCodeCaptchaVerification?> showEmailCodeCaptchaDialog({
  required BuildContext context,
  required ApiService apiService,
  required String purpose,
  String? username,
  String? email,
}) {
  return showDialog<EmailCodeCaptchaVerification>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => EmailCodeCaptchaDialog(
      apiService: apiService,
      purpose: purpose,
      username: username,
      email: email,
    ),
  );
}

class EmailCodeCaptchaDialog extends StatefulWidget {
  final ApiService apiService;
  final String purpose;
  final String? username;
  final String? email;

  const EmailCodeCaptchaDialog({
    super.key,
    required this.apiService,
    required this.purpose,
    this.username,
    this.email,
  });

  @override
  State<EmailCodeCaptchaDialog> createState() => _EmailCodeCaptchaDialogState();
}

class _EmailCodeCaptchaDialogState extends State<EmailCodeCaptchaDialog> {
  static const _blue = Color(0xFF12A8F4);
  EmailCodeCaptchaChallenge? _challenge;
  final List<int> _selected = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected.clear();
    });
    try {
      final challenge = await widget.apiService.createEmailCodeCaptcha(
        purpose: widget.purpose,
        username: widget.username,
        email: widget.email,
      );
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _challenge = null;
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _selectTile(int position) {
    if (_selected.contains(position) || _selected.length >= 3) return;
    setState(() => _selected.add(position));
  }

  void _submit() {
    final challenge = _challenge;
    if (challenge == null || _selected.length != 3) return;
    Navigator.of(context).pop(
      EmailCodeCaptchaVerification(
        captchaId: challenge.captchaId,
        captchaAnswer: List<int>.from(_selected),
      ),
    );
  }

  int? _selectionOrder(int position) {
    final index = _selected.indexOf(position);
    return index < 0 ? null : index + 1;
  }

  _CaptchaSymbol _symbolFor(String value) {
    return switch (value) {
      'circle' => const _CaptchaSymbol(Icons.circle, '圆点', Color(0xFF1677FF)),
      'triangle' =>
        const _CaptchaSymbol(Icons.change_history, '三角', Color(0xFF13A8A8)),
      'square' => const _CaptchaSymbol(Icons.square, '方块', Color(0xFF722ED1)),
      'diamond' => const _CaptchaSymbol(Icons.diamond, '菱形', Color(0xFFD46B08)),
      'star' => const _CaptchaSymbol(Icons.star, '星形', Color(0xFFD4A106)),
      'plus' => const _CaptchaSymbol(Icons.add, '十字', Color(0xFFEB2F96)),
      'moon' =>
        const _CaptchaSymbol(Icons.nightlight_round, '月牙', Color(0xFF597EF7)),
      'flower' =>
        const _CaptchaSymbol(Icons.local_florist, '花形', Color(0xFFCF1322)),
      'sparkle' =>
        const _CaptchaSymbol(Icons.auto_awesome, '闪光', Color(0xFF08979C)),
      _ => const _CaptchaSymbol(Icons.question_mark, '图案', Color(0xFF8C96A3)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: _blue),
          SizedBox(width: 8),
          Text('安全校验'),
        ],
      ),
      content: SizedBox(
        width: 330,
        child: _loading
            ? const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined,
                          size: 42, color: _blue),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadChallenge,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新加载'),
                      ),
                    ],
                  )
                : challenge == null
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '为保护邮箱验证码，请按顺序点按下方图案。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF5F6975)),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDF7FF),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFD4EDFF)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var index = 0;
                                    index < challenge.targetSequence.length;
                                    index++) ...[
                                  if (index > 0)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8),
                                      child: Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: Color(0xFF8C96A3),
                                      ),
                                    ),
                                  Icon(
                                    _symbolFor(challenge.targetSequence[index])
                                        .icon,
                                    color: _symbolFor(
                                            challenge.targetSequence[index])
                                        .color,
                                    size: 28,
                                    semanticLabel: _symbolFor(
                                      challenge.targetSequence[index],
                                    ).label,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 9,
                              crossAxisSpacing: 9,
                              childAspectRatio: 1.15,
                            ),
                            itemCount: challenge.tiles.length,
                            itemBuilder: (context, index) {
                              final tile = challenge.tiles[index];
                              final symbol = _symbolFor(tile.symbol);
                              final order = _selectionOrder(tile.position);
                              return Semantics(
                                button: true,
                                label:
                                    '选择${symbol.label}${order == null ? '' : '，第$order个'}',
                                child: InkWell(
                                  onTap: () => _selectTile(tile.position),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: order == null
                                          ? Colors.white
                                          : const Color(0xFFE6F4FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: order == null
                                            ? const Color(0xFFDCE9F3)
                                            : _blue,
                                        width: order == null ? 1 : 2,
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(symbol.icon,
                                            color: symbol.color, size: 30),
                                        if (order != null)
                                          Positioned(
                                            top: 3,
                                            right: 3,
                                            child: CircleAvatar(
                                              radius: 10,
                                              backgroundColor: _blue,
                                              child: Text(
                                                '$order',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : _loadChallenge,
          child: const Text('换一个图案'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _loading || _selected.length != 3 ? null : _submit,
          child: const Text('完成校验并发送'),
        ),
      ],
    );
  }
}

class _CaptchaSymbol {
  final IconData icon;
  final String label;
  final Color color;

  const _CaptchaSymbol(this.icon, this.label, this.color);
}
