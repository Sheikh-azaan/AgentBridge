import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

enum PipelineStepStatus {
  completed,
  active,
  pending,
  rejected,
  skipped,
}

class PipelineStepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;
  final PipelineStepStatus status;
  final Widget? content;
  final bool isLast;
  final IconData? icon;

  const PipelineStepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.status,
    this.content,
    this.isLast = false,
    this.icon,
  });

  Color _getStatusColor() {
    switch (status) {
      case PipelineStepStatus.completed:
        return AppColors.success;
      case PipelineStepStatus.active:
        return AppColors.primary;
      case PipelineStepStatus.pending:
        return AppColors.warning;
      case PipelineStepStatus.rejected:
        return AppColors.error;
      case PipelineStepStatus.skipped:
        return AppColors.textMuted;
    }
  }

  IconData _getDefaultIcon() {
    switch (status) {
      case PipelineStepStatus.completed:
        return Icons.check_circle_rounded;
      case PipelineStepStatus.active:
        return Icons.radio_button_checked_rounded;
      case PipelineStepStatus.pending:
        return Icons.hourglass_top_rounded;
      case PipelineStepStatus.rejected:
        return Icons.cancel_rounded;
      case PipelineStepStatus.skipped:
        return Icons.remove_circle_outline_rounded;
    }
  }

  String _getStatusLabel() {
    switch (status) {
      case PipelineStepStatus.completed:
        return 'COMPLETED';
      case PipelineStepStatus.active:
        return 'PROCESSING';
      case PipelineStepStatus.pending:
        return 'AWAITING APPROVAL';
      case PipelineStepStatus.rejected:
        return 'BLOCKED';
      case PipelineStepStatus.skipped:
        return 'SKIPPED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final stepIcon = icon ?? _getDefaultIcon();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left Column: Step badge + Vertical connector line ────────────
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: status == PipelineStepStatus.active
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    stepIcon,
                    size: 18,
                    color: color,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.7),
                          AppColors.border,
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // ── Right Column: Step Card ───────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: status == PipelineStepStatus.active
                        ? color.withValues(alpha: 0.5)
                        : AppColors.border,
                    width: status == PipelineStepStatus.active ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: Step #, Title, Status badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'STEP $stepNumber',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _getStatusLabel(),
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Content section (if provided)
                    if (content != null) ...[
                      const SizedBox(height: 12),
                      content!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
