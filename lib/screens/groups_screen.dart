import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/backend_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../utils/snackbar_util.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import 'group_detail_screen.dart';
import 'make_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  final bool isTab;
  const GroupsScreen({super.key, this.isTab = false});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildTabHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: Theme.of(context).textTheme.titleMedium,
                    decoration: const InputDecoration(
                      hintText: 'Search groups...',
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                  )
                : Text(
                    'Groups',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
          ),
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = "";
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTab) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _buildBody(context),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: Theme.of(context).textTheme.titleMedium,
                decoration: const InputDecoration(
                  hintText: 'Search groups...',
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              )
            : Text(
                'Groups',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = "";
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: _buildBody(context),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MakeGroupScreen()),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: Text(
          'New Group',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final user = BackendService.currentUser;

    if (!BackendService.isFirebaseReady || user == null) {
      return _buildEmptyState();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BackendService.groupsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(context);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data();

          if (_searchQuery.isEmpty) return true;
          final name = (data['name'] as String?)?.toLowerCase() ?? '';
          return name.contains(_searchQuery.toLowerCase());
        }).toList();

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...filteredDocs.asMap().entries.map((entry) {
              return TweenAnimationBuilder<double>(
                key: ValueKey(entry.value.id),
                duration: Duration(milliseconds: 400 + (entry.key * 100)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutQuart,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _groupCardFromDoc(context, entry.value),
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _groupCardFromDoc(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final accent = BackendService.colorFromValue(
      data['amountColor'],
      Theme.of(context).colorScheme.secondary,
    );
    final iconName = data['iconName'] as String?;
    final isTrip = iconName == 'flight';
    final groupId = doc.id;
    final createdBy = data['createdBy'] as String?;
    final isCreator = createdBy == null || createdBy == BackendService.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: CustomCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(groupId: groupId),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.12),
                border: Border.all(
                  color: accent.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                isTrip ? Icons.flight_takeoff : Icons.home,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'group-title-$groupId',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        (data['name'] as String?) ?? 'Group',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (data['type'] as String?) ?? 'Group',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: accent,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Builder(
                          builder: (context) {
                            final totalMembers = (data['memberIds'] as List?)?.length ?? ((data['memberCount'] as int?) ?? 0);
                            final friendsCount = (totalMembers > 0) ? totalMembers - 1 : 0;
                            return Text(
                              '$friendsCount friends',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isCreator) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _showDeleteDialog(context, groupId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 20,
              ),
            ],
            const SizedBox(width: 8),
            StreamBuilder<Map<String, dynamic>>(
              stream: BackendService.groupBalanceStream(groupId, BackendService.currentUser!.uid),
              builder: (context, balanceSnapshot) {
                double netBalance = 0;
                if (balanceSnapshot.hasData) {
                  final balancesMap = balanceSnapshot.data!['balances'] as Map<String, double>? ?? {};
                  for (final bal in balancesMap.values) {
                    netBalance += bal;
                  }
                }

                final isOwed = netBalance > 0.01;
                final isOwe = netBalance < -0.01;
                final balanceColor = isOwed
                    ? Theme.of(context).colorScheme.secondary
                    : (isOwe ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurfaceVariant);
                
                final balanceText = isOwed
                    ? 'you are owed'
                    : (isOwe ? 'you owe' : 'settled up');
                    
                final amountStr = isOwed || isOwe 
                    ? 'Rs. ${netBalance.abs().toStringAsFixed(0)}'
                    : 'Rs. 0';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      amountStr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: balanceColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      balanceText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
}

  void _showDeleteDialog(BuildContext context, String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await BackendService.deleteGroup(groupId);
                if (mounted) {
                  SnackbarUtil.showSuccess(context, 'Group deleted');
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  SnackbarUtil.showError(context, 'Failed to delete group: ${e.toString()}');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Column(
      children: [
        SizedBox(height: 60),
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          'No groups yet. Create one to start splitting bills.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load groups.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupsScreen()),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}