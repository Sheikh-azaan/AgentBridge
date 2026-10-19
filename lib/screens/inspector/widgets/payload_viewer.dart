import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';

class PayloadViewer extends StatefulWidget {
  final dynamic payload;
  final String label;
  final bool initialExpanded;
  final IconData? icon;

  const PayloadViewer({
    super.key,
    required this.payload,
    this.label = 'PAYLOAD',
    this.initialExpanded = true,
    this.icon,
  });

  @override
  State<PayloadViewer> createState() => _PayloadViewerState();
}

class _PayloadViewerState extends State<PayloadViewer> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  String _formatPayload() {
    if (widget.payload == null) return '// null';

    if (widget.payload is String) {
      final str = widget.payload as String;
      try {
        final decoded = jsonDecode(str);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        return str;
      }
    }

    if (widget.payload is Map || widget.payload is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(widget.payload);
      } catch (e) {
        return widget.payload.toString();
      }
    }

    return widget.payload.toString();
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.surface2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatted = _formatPayload();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070A0F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface2.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              border: Border(
                bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon ?? Icons.code_rounded,
                  size: 13,
                  color: AppColors.primaryGlow,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _copyToClipboard(context, formatted),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.copy_rounded, size: 12, color: AppColors.textMuted),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      _expanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                formatted,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: Color(0xFF67E8F9),
                  height: 1.45,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '${formatted.split('\n').take(2).join(' ')} ...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
