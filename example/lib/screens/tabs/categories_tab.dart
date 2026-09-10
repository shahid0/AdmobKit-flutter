import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../models/category_item.dart';
import '../../state/task_store.dart';
import '../../theme/task_theme.dart';
import '../sub_screens/category_tasks_screen.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final categories = CategoryItem.defaultCategories;

        return Scaffold(
          backgroundColor: TaskColors.canvasGround,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.18,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final count = store.tasks.where((t) => t.categoryId == cat.id).length;
                    return _buildCategoryCard(context, cat, count);
                  },
                ),
              ),
              _buildPinnedNativeAd(store.isPremium),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories & Workspaces',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: TaskColors.textInkPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Isolate cognitive context across focused domains.',
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
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, CategoryItem cat, int count) {
    return TactileButton(
      onTap: () {
        void navigate() {
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryTasksScreen(category: cat),
              ),
            );
          }
        }

        if (TaskStore.instance.checkInterval('category_navigation', interval: 3)) {
          TaskStore.instance.appendLog('📂 [Action] Category navigation threshold reached. Triggering Interstitial...');
          FlutterAds.show(
            SampleAds.mainInterstitial,
            onDismissed: navigate,
          );
        } else {
          navigate();
        }
      },
      child: TaskCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(cat.icon, color: cat.color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: TaskColors.textInkPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 1 ? '1 task' : '$count tasks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: TaskColors.textSlateMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedNativeAd(bool isPremium) {
    if (isPremium) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: TaskColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TaskColors.borderSubtle),
          boxShadow: TaskColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: TaskColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: TaskColors.borderSubtle),
                ),
                child: const Text(
                  'SPONSORED RECOMMENDATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: TaskColors.textMutedCaption,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            AdNativeView(
              placement: SampleAds.smallNative,
              height: 74,
              placeholder: Container(
                height: 74,
                decoration: BoxDecoration(
                  color: TaskColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TaskColors.borderSubtle),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.ads_click_rounded,
                  size: 20,
                  color: TaskColors.textMutedCaption,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
