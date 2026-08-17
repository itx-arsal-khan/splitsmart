import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/backend_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'package:lottie/lottie.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import '../widgets/custom_card.dart';

class HistoryScreen extends StatefulWidget {
  final bool isTab;
  const HistoryScreen({super.key, this.isTab = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'All';

  Widget _buildTabHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        'What Happened',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = BackendService.currentUser;

    if (!BackendService.isFirebaseReady || user == null) {
      return _wrapInScaffold(context, _buildEmptyState());
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BackendService.activitiesStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _wrapInScaffold(context, _buildLoadingState());
        }

        if (snapshot.hasError) {
          return _wrapInScaffold(context, _buildErrorState(context));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _wrapInScaffold(context, _buildEmptyState());
        }

        // Extract unique group names from activities
        final Set<String> uniqueGroups = {};
        for (var doc in docs) {
          final data = doc.data();
          final groupName = data['groupName'] as String?;
          if (groupName != null && groupName.isNotEmpty) {
            uniqueGroups.add(groupName);
          } else if (data['subIconName'] == 'group') {
            // Fallback for older activities
            final subText = data['subText'] as String?;
            if (subText != null && subText.isNotEmpty && subText != 'cash') {
              uniqueGroups.add(subText);
            }
          }
        }
        final filters = ['All', ...uniqueGroups.toList()..sort()];

        // Filter docs based on selection
        final filteredDocs = _selectedFilter == 'All'
            ? docs
            : docs.where((d) {
                final data = d.data();
                if (data['groupName'] == _selectedFilter) return true;
                if (data['subIconName'] == 'group' && data['subText'] == _selectedFilter) return true;
                return false;
              }).toList();

        final bodyContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isTab) _buildTabHeader(),
            // Filter chips
            SizedBox(
              height: 52,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                scrollDirection: Axis.horizontal,
                children: filters.map((f) {
                  final isSelected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () {
                        if (_selectedFilter != f) {
                          setState(() => _selectedFilter = f);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          f,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: CustomRefreshIndicator(
                onRefresh: () async {
                  // Simulate refresh delay to show the Lottie animation
                  await Future.delayed(const Duration(seconds: 2));
                  setState(() {});
                },
                builder: (BuildContext context, Widget child, IndicatorController controller) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      if (!controller.isIdle)
                        Positioned(
                          top: 20.0 + (30.0 * controller.value),
                          child: SizedBox(
                            height: 60,
                            width: 60,
                            child: Lottie.asset(
                              'assets/animations/coin.json',
                              fit: BoxFit.contain,
                              animate: controller.isLoading || controller.isArmed,
                            ),
                          ),
                        ),
                      Transform.translate(
                        offset: Offset(0, 100.0 * controller.value),
                        child: child,
                      ),
                    ],
                  );
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: 1 + filteredDocs.length + (filteredDocs.isEmpty ? 1 : 0) + (filteredDocs.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        child: _bannerCard(),
                      );
                    }
                    
                    int itemIndex = index - 1;
                    
                    if (filteredDocs.isEmpty) {
                      if (itemIndex == 0) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'No activities for $_selectedFilter.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    
                    if (itemIndex < filteredDocs.length) {
                      final data = filteredDocs[itemIndex].data();
                      final isLast = itemIndex == filteredDocs.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _firebaseTimelineItem(data, isLast),
                      );
                    } else if (itemIndex == filteredDocs.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xl),
                        child: _bottomMessage(),
                      );
                    }
                    
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        );

        return _wrapInScaffold(context, bodyContent);
      },
    );
  }

  Widget _wrapInScaffold(BuildContext context, Widget child) {
    if (widget.isTab) return child;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'What Happened',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: child,
    );
  }
  // ---------- Banner Card ----------
  Widget _bannerCard() {
    return CustomCard(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(AppSpacing.xl),
      hasShadow: false,
      child: Column(
        children: [
          Text(
            'Timeline of spends',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Keeping track for everyone',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Bottom End Message ----------
  Widget _bottomMessage() {
    return Column(
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 36,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "That's everything for now",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ---------- Firebase Timeline Item ----------
  Widget _firebaseTimelineItem(Map<String, dynamic> data, bool isLast) {
    final textParts =
        (data['textParts'] as List<dynamic>? ?? ['Update', ' activity']);

    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 19, // 40 (icon width) / 2 - 1 (line half width)
            top: 40, // Start below the icon
            bottom: 0,
            child: Container(
              width: 2,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline icon
            SizedBox(
              width: 40,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BackendService.colorFromValue(
                    data['iconBg'],
                    Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
                child: Icon(
                  BackendService.iconFromName(data['iconName'] as String?),
                  color: BackendService.colorFromValue(
                    data['iconColor'],
                    Theme.of(context).colorScheme.primary,
                  ),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Card
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: CustomCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              children: [
                                TextSpan(
                                  text: textParts[0].toString(),
                                ),
                                if (textParts.length > 1)
                                  TextSpan(
                                    text: textParts[1].toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          (data['timeText'] as String?) ?? 'Just now',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      (data['amountText'] as String?) ?? 'Rs. 0',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: BackendService.colorFromValue(
                          data['amountColor'],
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          BackendService.iconFromName(
                            data['subIconName'] as String?,
                          ),
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            (data['subText'] as String?) ?? '',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ],
    );
  }

  // ---------- Loading / Empty / Error States ----------
  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        _bannerCard(),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No activities yet.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Add a bill or settle a debt to see it here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _bottomMessage(),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Column(
      children: [
        _bannerCard(),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Could not load activities.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () {
                    setState(() {}); // rebuild stream
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _bottomMessage(),
      ],
    );
  }
}