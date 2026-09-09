import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../state/task_store.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  void _exportReport(BuildContext context) {
    final store = TaskStore.instance;

    if (store.isPremium) {
      _showReportSuccessDialog(context);
      return;
    }

    // Free tier: Gated behind a Rewarded Ad
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        title: const Row(
          children: [
            Icon(Icons.video_collection_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Watch Ad to Export', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Watch a short rewarded ad to generate and export your complete task productivity PDF report for free.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              store.appendLog('🎬 [Rewarded] User opted in to watch Rewarded Ad for PDF Export.');

              FlutterAds.show(
                SampleAds.rewardedBonus,
                onDismissed: () {
                  store.appendLog('🎬 [Rewarded] Video ad dismissed.');
                },
                onRewardGranted: (amount, type) {
                  store.appendLog('🎁 [Rewarded] Reward granted: $amount $type!');
                  _showReportSuccessDialog(context);
                },
              );
            },
            child: const Text('Watch Ad & Export'),
          ),
        ],
      ),
    );
  }

  void _showReportSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Report Generated', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Your Q3 Task Productivity PDF report has been compiled and saved to downloads.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFF6366F1))),
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
        final completionRate = store.totalTasksCount == 0
            ? 0
            : ((store.completedTasksCount / store.totalTasksCount) * 100).toInt();

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF14141A),
            title: const Text('Productivity Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlight Score Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weekly Velocity',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$completionRate%',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${store.completedTasksCount} of ${store.totalTasksCount} tasks completed',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.trending_up_rounded, size: 64, color: Colors.white24),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Metrics Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),

                // Stat Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('Streak', '5 Days', Icons.local_fire_department_rounded, const Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard('Pending', '${store.pendingTasksCount}', Icons.pending_actions_rounded, const Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard('Done', '${store.completedTasksCount}', Icons.task_alt_rounded, const Color(0xFF10B981)),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Export Button Gated by Rewarded Ad
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEC4899)),
                          const SizedBox(width: 8),
                          const Text(
                            'Weekly Accomplishment Report',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                          ),
                          const Spacer(),
                          if (!store.isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'REWARDED AD',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Generate a structured PDF summarizing your completed tasks, hours logged, and category focus distribution.',
                        style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text(store.isPremium ? 'Export PDF (Pro Unlocked)' : 'Watch Ad to Export PDF'),
                          onPressed: () => _exportReport(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ],
      ),
    );
  }
}
