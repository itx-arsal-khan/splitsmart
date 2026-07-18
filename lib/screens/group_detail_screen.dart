import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/backend_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../utils/snackbar_util.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/avatar_widget.dart';
import 'add_bill_screen.dart';
import 'pay_back_screen.dart';
import 'settle_up_flow_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  void _showSettingsBottomSheet(BuildContext context, {String? groupId, String? currentName}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Rename Group', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, groupId: groupId, currentName: currentName);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('Delete Group', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmationDialog(context, groupId: groupId);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Cancel', style: Theme.of(context).textTheme.titleMedium),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, {String? groupId, String? currentName}) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Group Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);

              if (groupId == null) {
                SnackbarUtil.showSuccess(context, 'Renamed group (local demo)');
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .update({'name': newName});
                if (mounted) {
                  SnackbarUtil.showSuccess(context, 'Group renamed successfully');
                }
              } catch (e) {
                if (mounted) {
                  SnackbarUtil.showError(context, 'Failed to rename group: ${e.toString()}');
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, {String? groupId}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone and will delete all group records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              if (groupId == null) {
                Navigator.pop(context);
                SnackbarUtil.showSuccess(context, 'Group deleted (local demo)');
                return;
              }

              try {
                await BackendService.deleteGroup(groupId);
                if (mounted) {
                  SnackbarUtil.showSuccess(context, 'Group deleted successfully');
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  SnackbarUtil.showError(context, 'Failed to delete group: ${e.toString()}');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = BackendService.currentUser;

    if (!BackendService.isFirebaseReady || user == null) {
      return _buildErrorScreen(context, 'Firebase Connection Error');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: BackendService.groupStream(widget.groupId),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.hasError) {
          return _buildErrorScreen(context, 'Could not load group details.');
        }
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        final groupData = groupSnapshot.data?.data();
        if (groupData == null) {
          return _buildErrorScreen(context, 'Group not found.');
        }

        final groupName = groupData['name'] as String? ?? 'Group';
        final groupType = groupData['type'] as String? ?? 'Group';
        final accentColor = BackendService.colorFromValue(
          groupData['amountColor'],
          Theme.of(context).colorScheme.secondary,
        );
        final memberIds = List<String>.from(groupData['memberIds'] ?? []);
        final createdBy = groupData['createdBy'] as String?;
        final isCreator = createdBy == null || createdBy == user.uid;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            title: Hero(
              tag: 'group-title-${widget.groupId}',
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      groupName,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        groupType,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 18,
                  ),
                ),
                onPressed: () => _showSettingsBottomSheet(
                  context,
                  groupId: widget.groupId,
                  currentName: groupName,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Group Members ----------
                Text(
                  'GROUP MEMBERS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildMembersSection(context, memberIds, groupName, isCreator),
                const SizedBox(height: AppSpacing.xl),

                // ---------- Who Owes Who ----------
                _buildWhoOwesWho(context, widget.groupId, groupName, memberIds, isCreator),
                const SizedBox(height: AppSpacing.xl),

                // ---------- Bills in This Group ----------
                _buildBillsSection(context, widget.groupId),
                const SizedBox(height: 80),
              ],
            ),
          ),
          floatingActionButton: isCreator ? FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddBillScreen(groupId: widget.groupId),
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.add),
          ) : null,
        );
      },
    );
  }

  // ---------- Members Section ----------
  Widget _buildMembersSection(
    BuildContext context,
    List<String> memberIds,
    String groupName,
    bool isCreator,
  ) {
    if (memberIds.isEmpty) {
      return Text('No members yet.', style: Theme.of(context).textTheme.bodyMedium);
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: BackendService.getUsersByIds(memberIds),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load members.');
        }
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final allUsers = snapshot.data!;
        final users = allUsers.where((u) => u['uid'] != BackendService.currentUser?.uid).toList();
        const maxDisplay = 4;
        final displayed = users.take(maxDisplay).toList();
        final remaining = users.length - maxDisplay;

        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 12,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...displayed.asMap().entries.map((entry) {
                  final index = entry.key;
                  final userData = entry.value;
                  final name = userData['name'] as String? ?? '?';
                  final uid = userData['uid'] as String? ?? '';
                  final initials = BackendService.initialsFromName(name);
                  final isSelf = uid == BackendService.currentUser?.uid;

                  return TweenAnimationBuilder<double>(
                    key: ValueKey(uid),
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, val, child) {
                      return Transform.scale(
                        scale: val.clamp(0.0, 1.0),
                        child: child,
                      );
                    },
                    child: GestureDetector(
                      onLongPress: () {
                        if (!isCreator) return;
                        if (isSelf) {
                          SnackbarUtil.showError(context, 'You cannot remove yourself');
                          return;
                        }
                        _showRemoveMemberDialog(context, widget.groupId, uid, name);
                      },
                      child: Transform.translate(
                        offset: Offset(index * -8.0, 0),
                        child: AvatarWidget(
                          initials: initials,
                          size: 44,
                          backgroundColor: _getColorForIndex(index, context),
                          textColor: Colors.white,
                        ),
                      ),
                    ),
                  );
                }),
                if (remaining > 0)
                  Transform.translate(
                    offset: const Offset(-32, 0),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '+$remaining',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isCreator) ElevatedButton.icon(
              onPressed: () => _showAddMemberDialog(context, widget.groupId, memberIds),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: Text(
                'search people',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.radiusXl,
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- Add Member Dialog ----------
  void _showAddMemberDialog(BuildContext context, String groupId, List<String> currentMemberIds) {
    final TextEditingController searchController = TextEditingController();
    Map<String, dynamic>? searchedUser;
    bool hasSearched = false;
    bool isSearching = false;
    Timer? debounce;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Member'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Enter username or phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (query) {
                    if (debounce?.isActive ?? false) debounce!.cancel();
                    
                    if (query.trim().isEmpty) {
                      setState(() {
                        searchedUser = null;
                        hasSearched = false;
                        isSearching = false;
                      });
                      return;
                    }

                    setState(() {
                      isSearching = true;
                      hasSearched = true;
                    });

                    debounce = Timer(const Duration(milliseconds: 500), () async {
                      final user = await BackendService.searchUserByPhoneOrUsername(query);
                      if (ctx.mounted) {
                        setState(() {
                          searchedUser = user;
                          isSearching = false;
                        });
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (isSearching)
                  const CircularProgressIndicator()
                else if (hasSearched && searchedUser == null)
                  const Text('No user found with that username or phone number.')
                else if (searchedUser != null)
                  Builder(
                    builder: (context) {
                      final uid = searchedUser!['uid'] as String?;
                      final name = searchedUser!['name'] as String? ?? 'Unknown';
                      final username = searchedUser!['username'] as String? ?? '';
                      final isAlreadyAdded = currentMemberIds.contains(uid);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text('User Found:', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(name),
                            subtitle: Text('@$username'),
                            trailing: isAlreadyAdded
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : ElevatedButton(
                                    onPressed: () async {
                                      if (uid == null) return;
                                      
                                      // Confirmation step
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Confirm Add'),
                                          content: Text('Add $name (@$username) to this group?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(c, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(c, true),
                                              child: const Text('Add'),
                                            ),
                                          ],
                                        )
                                      );

                                      if (confirm != true) return;

                                      try {
                                        await BackendService.addMemberToGroup(groupId, uid);
                                        if (context.mounted) {
                                          Navigator.pop(ctx);
                                          SnackbarUtil.showSuccess(context, '$name added to group');
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          SnackbarUtil.showError(context, 'Failed to add: ${e.toString()}');
                                        }
                                      }
                                    },
                                    child: const Text('Add'),
                                  ),
                          ),
                        ],
                      );
                    }
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Remove Member Dialog ----------
  void _showRemoveMemberDialog(BuildContext context, String groupId, String memberUid, String memberName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $memberName'),
        content: const Text('Are you sure you want to remove this member from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await BackendService.removeMemberFromGroup(groupId, memberUid);
                if (context.mounted) {
                  SnackbarUtil.showSuccess(context, '$memberName removed');
                  setState(() {});
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarUtil.showError(context, 'Failed to remove: ${e.toString()}');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ---------- Who Owes Who ----------
  Widget _buildWhoOwesWho(BuildContext context, String groupId, String groupName, List<String> memberIds, bool isCreator) {
    final uid = BackendService.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<Map<String, dynamic>>(
      stream: BackendService.groupBalanceStream(groupId, uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Error loading balances');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final balances = data['balances'] as Map<String, double>? ?? {};

        // Include all members with 0 balance
        for (final mId in memberIds) {
          if (!balances.containsKey(mId)) {
            balances[mId] = 0.0;
          }
        }

        final hasBills = data['hasBills'] as bool? ?? false;

        if (!hasBills) {
          return CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Who Owes Who Here',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No bills added yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final sorted = balances.entries.toList()
          ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

        // Resolve names for all members involved in balances
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: BackendService.getUsersByIds(sorted.map((e) => e.key).toList()),
          builder: (context, nameSnapshot) {
            final nameMap = nameSnapshot.data ?? [];

            return CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Who Owes Who Here',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...sorted.asMap().entries.map((listEntry) {
                    final index = listEntry.key;
                    final entry = listEntry.value;
                    final targetUid = entry.key;
                    final balance = entry.value;
                    final targetUserData = nameMap.firstWhere(
                      (u) => u['uid'] == targetUid,
                      orElse: () => {'name': 'Someone'},
                    );
                    String name = targetUserData['name'] as String? ?? 'Someone';
                    if (targetUid == uid) {
                      name = '$name (you)';
                    }
                    final isPositive = balance > 0;
                    final isZero = balance.abs() <= 0.01;
                    final amountText = isZero
                        ? 'settled up'
                        : (isPositive ? 'owes you Rs. ${balance.toStringAsFixed(0)}' : 'you owe Rs. ${balance.abs().toStringAsFixed(0)}');
                    final color = isZero ? Theme.of(context).colorScheme.onSurfaceVariant : (isPositive ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.error);

                    final totalOwed = (data['totalOwedToUser'] as num?)?.toDouble() ?? 0;
                    final totalOwes = (data['totalUserOwes'] as num?)?.toDouble() ?? 0;
                    final divisor = isPositive ? totalOwed : totalOwes;
                    final progress = divisor > 0 ? (balance.abs() / divisor) : 0.0;

                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutBack,
                      builder: (context, val, child) {
                        return Transform.scale(
                          scale: val.clamp(0.0, 1.0),
                          child: Opacity(
                            opacity: val.clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _owesRow(context, name, amountText, color, progress),
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                  if (isCreator) CustomButton(
                    text: 'Settle Up',
                    type: ButtonType.primary,
                    onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettleUpMembersScreen(
                                groupId: groupId,
                                groupName: groupName,
                              ),
                            ),
                          );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------- Bills Section ----------
  Widget _buildBillsSection(BuildContext context, String groupId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Bills in This Group',
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.chevron_right, size: 18),
              label: Text(
                'See All',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: BackendService.billsForGroupStream(groupId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Could not load bills.');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Text('No bills in this group yet.');
            }

            return CustomCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: docs.asMap().entries.map((entry) {
                  final data = entry.value.data();
                  return TweenAnimationBuilder<double>(
                    key: ValueKey(entry.key),
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
                    child: _buildBillItem(
                      context,
                      icon: BackendService.iconFromName(
                        data['iconName'] as String?,
                      ),
                      iconBg: BackendService.colorFromValue(
                        data['iconBg'],
                        Theme.of(context).colorScheme.primaryContainer,
                      ),
                      iconColor: BackendService.colorFromValue(
                        data['iconColor'],
                        Theme.of(context).colorScheme.primary,
                      ),
                      title: data['title'] as String? ?? 'Bill',
                      paidBy: data['createdByName'] as String? ?? 'Someone',
                      amount: data['amountText'] as String? ?? 'Rs. 0',
                      status: data['statusText'] as String? ?? 'Pending',
                      statusColor: BackendService.colorFromValue(
                        data['statusColor'],
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      showDivider: entry.key != docs.length - 1,
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------- Bill Item Widget ----------
  Widget _buildBillItem(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String paidBy,
    required String amount,
    required String status,
    required Color statusColor,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.radiusMd,
                  color: iconBg.withValues(alpha: 0.2),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Paid by $paidBy',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  // ---------- Helper for colors ----------
  Color _getColorForIndex(int index, BuildContext context) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.amber.shade700,
    ];
    return colors[index % colors.length];
  }

  // ---------- Owes Row ----------
  Widget _owesRow(BuildContext context, String name, String amount, Color color, double progress) {
    return Column(
      children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  amount,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorScreen(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}