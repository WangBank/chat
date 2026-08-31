import 'package:flutter/material.dart';
import '../utils/network_error.dart';

String normalizeErrorMessage(Object? error, {String fallback = '请求失败'}) {
  if (isServiceUnavailableError(error)) return serviceMaintenanceMessage;

  final raw = error?.toString().trim() ?? '';
  if (raw.isEmpty) return fallback;

  var message = raw;
  var changed = true;
  while (changed) {
    final next = message
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Error:\s*'), '')
        .trim();
    changed = next != message;
    message = next;
  }

  return message.isEmpty ? fallback : message;
}

void showCompactErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      content: Text(
        message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class LoadErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String? details;
  final VoidCallback onRetry;
  final IconData icon;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;

  const LoadErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.accentColor,
    required this.textColor,
    required this.mutedColor,
    this.details,
    this.icon = Icons.cloud_off_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedDetails = normalizeErrorMessage(details, fallback: '');

    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - 32).clamp(0.0, double.infinity)
            : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(icon, size: 40, color: accentColor),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    if (normalizedDetails.isNotEmpty &&
                        normalizedDetails != serviceMaintenanceMessage) ...[
                      const SizedBox(height: 14),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 110),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE1E8EF)),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            normalizedDetails,
                            style: const TextStyle(
                              color: Color(0xFF5F6975),
                              fontSize: 12,
                              height: 1.35,
                            ),
                            softWrap: true,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
