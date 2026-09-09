import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../state/task_store.dart';
import '../../theme/task_theme.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  void _exportReport(BuildContext context) {
    final store = TaskStore.instance;

    if (store.isPremium) {
      store.appendLog('📄 [Export] VIP user compiled accomplishment report instantly.');
      _showReportSuccessDialog(context);
      return;
    }

    store.appendLog('🎬 [Rewarded] User opted in to watch Rewarded Ad for PDF Export.');
    FlutterAds.show(
      SampleAds.rewardedBonus,
      onDismissed: () {
        store.appendLog('🎬 [Rewarded] Video ad dismissed.');
      },
      onRewardGranted: (amount, type) {
        store.appendLog('🎁 [Rewarded] Reward granted: $amount $type!');
        if (context.mounted) {
          _showReportSuccessDialog(context);
        }
      },
    );
  }

  void _showReportSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TaskColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: TaskColors.borderSubtle),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: TaskColors.emeraldText,
              size: 22,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Report Compiled',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: TaskColors.textInkPrimary,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your executive accomplishment PDF report has been compiled successfully.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: TaskColors.textSlateMedium,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: TaskColors.accentPrimary,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final total = store.totalTasksCount;
        final completed = store.completedTasksCount;
        final completionRate = total == 0 ? 0 : ((completed / total) * 100).toInt();

        return Scaffold(
          backgroundColor: TaskColors.canvasGround,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildVelocityCard(completionRate, completed, total),
                const SizedBox(height: 16),
                _buildStatCardsRow(store),
                const SizedBox(height: 20),
                _buildExportCard(context, store.isPremium),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Productivity Velocity',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: TaskColors.textInkPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Quantitative completion momentum across active initiatives.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: TaskColors.textSlateMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildVelocityCard(int completionRate, int completed, int total) {
    return TaskCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Completion Velocity',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: TaskColors.textSlateMedium,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: TaskColors.accentSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: TaskColors.accentPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$completionRate%',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: TaskColors.textInkPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(10, (index) {
              final segmentThreshold = (index + 1) * 10;
              final isFilled = completionRate >= segmentThreshold;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: index < 9 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: isFilled ? TaskColors.accentPrimary : TaskColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            '$completed of $total tasks completed',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: TaskColors.textSlateMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardsRow(TaskStore store) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Current Streak',
            value: '5 Days',
            icon: Icons.local_fire_department_rounded,
            iconColor: TaskColors.amberText,
            iconBgColor: TaskColors.amberSurface,
            borderColor: TaskColors.amberBorder,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'Pending Tasks',
            value: '${store.pendingTasksCount}',
            icon: Icons.pending_actions_rounded,
            iconColor: TaskColors.accentPrimary,
            iconBgColor: TaskColors.accentSubtle,
            borderColor: TaskColors.borderSubtle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'Completed Tasks',
            value: '${store.completedTasksCount}',
            icon: Icons.task_alt_rounded,
            iconColor: TaskColors.emeraldText,
            iconBgColor: TaskColors.emeraldSurface,
            borderColor: TaskColors.emeraldBorder,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required Color borderColor,
  }) {
    return TaskCard(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: TaskColors.textInkPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: TaskColors.textSlateMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard(BuildContext context, bool isPremium) {
    return TaskCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: TaskColors.accentSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 18,
                  color: TaskColors.accentPrimary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Executive Accomplishment Report',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: TaskColors.textInkPrimary,
                  ),
                ),
              ),
              if (!isPremium) ...[
                const SizedBox(width: 8),
                StatusBadge.amber('REWARDED EXPORT'),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Generate a structured PDF summarizing task completion velocity and workspace distribution.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: TaskColors.textSlateMedium,
            ),
          ),
          const SizedBox(height: 16),
          TactileButton(
            onTap: () => _exportReport(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: TaskColors.accentPrimary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: TaskColors.accentPrimary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPremium ? Icons.download_rounded : Icons.play_circle_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isPremium ? 'Export PDF (VIP Instant)' : 'Watch Ad to Export PDF',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
