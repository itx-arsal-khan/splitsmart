import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/backend_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/avatar_widget.dart';
import 'add_bill_screen.dart';
import 'pay_back_screen.dart';
import 'groups_screen.dart';
import 'settle_up_flow_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'make_group_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'instructions_screen.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import '../services/notification_service.dart';
import '../utils/snackbar_util.dart';
import 'group_detail_screen.dart';
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final PageController _pageController;

  late final AnimationController _pulseController;
  
  StreamSubscription? _notificationsSub;
  StreamSubscription? _balanceSub;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    BackendService.cleanupCorruptedSettlements();
    BackendService.cleanupOrphanedData();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _checkFirstTimeUser();
    _setupNotificationListeners();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("Failed to get initial deep link: $e");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint("Deep link error: $err");
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'splitsmart' && uri.host == 'join') {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final groupId = pathSegments.first;
        _joinGroup(groupId);
      }
    }
  }

  Future<void> _joinGroup(String groupId) async {
    final user = BackendService.currentUser;
    if (user == null) {
      SnackbarUtil.showError(context, 'You must be logged in to join a group.');
      return;
    }
    
    try {
      await BackendService.addMemberToGroup(groupId, user.uid);
      if (mounted) {
         SnackbarUtil.showSuccess(context, 'Successfully joined the group!');
         Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)));
      }
    } catch (e) {
      if (mounted) {
         SnackbarUtil.showError(context, 'Failed to join group: $e');
      }
    }
  }

  void _showJoinGroupDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group Code',
            hintText: 'Enter group code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
               final code = controller.text.trim();
               if (code.isNotEmpty) {
                 Navigator.pop(ctx);
                 _joinGroup(code);
               }
            },
            child: const Text('Join'),
          )
        ],
      ),
    );
  }

  Future<void> _checkFirstTimeUser() async {
    final user = BackendService.currentUser;
    if (user == null) return;

    final creationTime = user.metadata.creationTime;
    if (creationTime == null) return;

    // Only show to users whose account was created very recently (e.g., within the last hour)
    // This prevents old users logging into a new device from seeing it.
    final isNewAccount = DateTime.now().difference(creationTime).inHours < 1;
    if (!isNewAccount) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenToast = prefs.getBool('has_seen_instruction_toast') ?? false;
    if (!hasSeenToast) {
      await prefs.setBool('has_seen_instruction_toast', true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.help_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Tap ? for a quick guide',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 30, left: 50, right: 50),
            elevation: 8,
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        );
      }
    }
  }

  void _setupNotificationListeners() {
    final user = BackendService.currentUser;
    if (user == null || !BackendService.isFirebaseReady) return;

    _notificationsSub = BackendService.notificationsStream(user.uid)?.listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          // We only want to show push notifications for recent items that are unread
          if (data != null && data['read'] != true) {
            final createdAt = data['createdAt'] as Timestamp?;
            if (createdAt != null) {
               // Only show local push notification if it was created in the last minute 
               // (prevents showing all past unread notifications on load)
               if (DateTime.now().difference(createdAt.toDate()).inMinutes < 2) {
                 final type = data['type'] as String?;
                 if (type == 'group_invite' || type == 'bill_added' || type == 'settlement') {
                    NotificationService.showInstantNotification(
                      id: change.doc.id.hashCode,
                      title: type == 'group_invite' ? 'New Group Invite' : (type == 'settlement' ? 'Settlement' : 'New Bill Added'),
                      body: data['message'] as String? ?? 'You have a new notification',
                    );
                 }
               }
            }
          }
        }
      }
    });

    _balanceSub = BackendService.userBalanceStream(user.uid)?.listen((data) {
      final totalUserOwes = (data['totalUserOwes'] as num?)?.toDouble() ?? 0;
      if (totalUserOwes > 0) {
        NotificationService.scheduleDailyReminder(
          id: 100,
          title: 'SplitSmart Reminder',
          body: 'You have pending payments of Rs. ${totalUserOwes.toStringAsFixed(0)}. Settle up today!',
          timeOfDay: const TimeOfDay(hour: 10, minute: 0),
        );
      } else {
        NotificationService.cancelNotification(100);
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _notificationsSub?.cancel();
    _balanceSub?.cancel();
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          physics: const BouncingScrollPhysics(),
          children: [
            // Tab 0: Home dashboard
            Column(
              children: [
                _buildTopAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        _buildHeroCard(context),
                        const SizedBox(height: AppSpacing.xl),
                        _buildQuickActions(context),
                        const SizedBox(height: 40),
                        _buildWhoOwesWho(context),
                        const SizedBox(height: 40),
                        _buildRecentBills(context),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Tab 1: Groups (embedded as tab)
            const GroupsScreen(isTab: true),
            // Tab 2: History (embedded as tab)
            const HistoryScreen(isTab: true),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MakeGroupScreen()),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.add),
              label: Text(
                'New Group',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
              ),
            )
          : null,
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  // ---------- Top App Bar ----------
  Widget _buildTopAppBar(BuildContext context) {
    final user = BackendService.currentUser;

    if (!BackendService.isFirebaseReady || user == null) {
      return _staticTopAppBar(
        context,
        greeting: 'Hello 👋',
        displayName: 'Guest',
        initials: 'G',
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: BackendService.userProfileStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return _staticTopAppBar(
            context,
            greeting: 'Hello, Guest 👋',
            displayName: 'Guest',
            initials: 'G',
          );
        }
        final data = snapshot.data?.data();
        final name = (data?['name'] as String?)?.trim();
        final displayName = (name != null && name.isNotEmpty)
            ? name
            : BackendService.displayNameForUser(user);
        final greeting = 'Hello, ${displayName.split(' ').first} 👋';

        final photoUrl = data?['photoUrl'] as String?;

        return _staticTopAppBar(
          context,
          greeting: greeting,
          displayName: displayName,
          initials: BackendService.initialsFromName(displayName),
          photoUrl: photoUrl,
        );
      },
    );
  }

  Widget _staticTopAppBar(
    BuildContext context, {
    required String greeting,
    required String displayName,
    required String initials,
    String? photoUrl,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: AvatarWidget(initials: initials, imageUrl: photoUrl, size: 52),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
            tooltip: 'How to use',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InstructionsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Hero Card (Real Balance) ----------
  Widget _buildHeroCard(BuildContext context) {
    final user = BackendService.currentUser;

    if (!BackendService.isFirebaseReady || user == null) {
      return _heroCardShell(
        context,
        heading: 'You Are Owed',
        amount: 'Rs. 0',
        amountColor: Theme.of(context).colorScheme.secondary,
        subtitle: 'All settled up',
      );
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: BackendService.userBalanceStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _heroCardShell(
            context,
            heading: 'Error',
            amount: 'Rs. 0',
            amountColor: Theme.of(context).colorScheme.error,
            subtitle: 'could not load balance',
          );
        }
        if (!snapshot.hasData) {
          return _heroCardShell(
            context,
            heading: 'Loading...',
            amount: 'Rs. --',
            amountColor: Theme.of(context).colorScheme.onSurfaceVariant,
            subtitle: 'please wait',
          );
        }

        final data = snapshot.data!;
        final netBalance = (data['netBalance'] as num?)?.toDouble() ?? 0;
        final isPositive = netBalance >= 0;
        final heading = isPositive ? 'You Are Owed' : 'You Owe';
        final amountColor = isPositive ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.error;
        final subtitle = netBalance == 0 ? 'all settled up' : '';

        return _heroCardShell(
          context,
          heading: heading,
          amount: 'Rs. ${netBalance.abs().toStringAsFixed(0)}',
          amountColor: amountColor,
          subtitle: subtitle,
        );
      },
    );
  }

  Widget _heroCardShell(
    BuildContext context, {
    required String heading,
    required String amount,
    required Color amountColor,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1B4B) : Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
          // Subtle pulse effect on the gradient opacity
          final glowOpacity = 0.8 + (_pulseController.value * 0.2);
          
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: AppRadii.radiusXl,
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppShadows.darkShadow.first.color : Theme.of(context).colorScheme.primary.withOpacity(0.3 * _pulseController.value),
                  blurRadius: 20 + (10 * _pulseController.value),
                  offset: const Offset(0, 10),
                )
              ],
              gradient: LinearGradient(
                colors: [
                  cardColor,
                  isDark ? const Color(0xFF312E81) : Theme.of(context).colorScheme.primary.withOpacity(glowOpacity),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: child,
          );
        },
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -40,
            right: -20,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                // Circular floating path
                final dx = math.cos(_pulseController.value * 2 * math.pi) * 10;
                final dy = math.sin(_pulseController.value * 2 * math.pi) * 10;
                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: child,
                );
              },
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ]
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      amount,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white, // keep it white on the dark primary card, it's cleaner
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Quick Actions ----------
  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Add Bill',
            icon: Icons.add,
            type: ButtonType.primary,
            onPressed: () => Navigator.push(
               context,
               MaterialPageRoute(builder: (_) => const AddBillScreen()),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: CustomButton(
            text: 'Settle Up',
            icon: Icons.payments,
            type: ButtonType.outline,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettleUpGroupsScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: CustomButton(
            text: 'Join',
            icon: Icons.group_add,
            type: ButtonType.secondary,
            onPressed: () => _showJoinGroupDialog(context),
          ),
        ),
      ],
    );
  }

  // ---------- Who Owes Who (Real) ----------
  Widget _buildWhoOwesWho(BuildContext context) {
    final user = BackendService.currentUser;

    if (!BackendService.isFirebaseReady || user == null) {
      return _buildEmptySection(context, 'Who Owes Who', 'All settled up!');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BackendService.groupsStream(user.uid),
      builder: (context, groupsSnapshot) {
        return StreamBuilder<Map<String, dynamic>>(
          stream: BackendService.userBalanceStream(user.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorSection(context, 'Who Owes Who', 'Could not load balances');
            }
            if (!snapshot.hasData) {
              return _buildLoadingSection(context, 'Who Owes Who');
            }

            final data = snapshot.data!;
            final balances = data['balances'] as Map<String, double>? ?? {};

            // Add all missing members from groups with 0 balance
            if (groupsSnapshot.hasData) {
              final docs = groupsSnapshot.data!.docs;
              for (final doc in docs) {
                final data = doc.data();
                final createdBy = data['createdBy'] as String?;
                if (createdBy != null && createdBy != user.uid) continue;

                final memberIds = List<String>.from(data['memberIds'] ?? []);
                for (final mId in memberIds) {
                  if (!balances.containsKey(mId)) {
                    balances[mId] = 0.0;
                  }
                }
              }
            }

            // Make sure the current user is always included if there's any data
            if (!balances.containsKey(user.uid) && balances.isNotEmpty) {
              balances[user.uid] = 0.0;
            }

            final sorted = balances.entries.toList()
              ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
            final top = sorted.take(4).toList();

            if (top.isEmpty) {
              return _buildEmptySection(context, 'Who Owes Who', 'All settled up!');
            }

        // Resolve names asynchronously
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _resolveNames(top.map((e) => e.key).toList()),
          builder: (context, nameSnapshot) {
            final nameMap = nameSnapshot.data ?? [];
            
            // Calculate max balance for progress bar
            final maxBalance = top.fold<double>(0, (max, e) => e.value.abs() > max ? e.value.abs() : max);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Who Owes Who',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GroupsScreen()),
                        );
                      },
                      child: Text(
                        'View All',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ...top.map((entry) {
                  final uid = entry.key;
                  final balance = entry.value;
                  final userData = nameMap.firstWhere(
                    (u) => u['uid'] == uid,
                    orElse: () => {'name': 'Unknown'},
                  );
                  String name = userData['name'] as String? ?? 'Unknown';
                  if (uid == user.uid) {
                    name = '$name (you)';
                  }
                  final isPositive = balance > 0;
                  final isZero = balance.abs() <= 0.01;
                  
                  String amountText;
                  if (isZero) {
                    amountText = 'Settled';
                  } else if (isPositive) {
                    amountText = 'owes you Rs. ${balance.toStringAsFixed(0)}';
                  } else {
                    amountText = 'you owe Rs. ${balance.abs().toStringAsFixed(0)}';
                  }

                  final color = isZero ? Theme.of(context).colorScheme.onSurfaceVariant : (isPositive ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.error);
                  final progress = maxBalance > 0 ? (balance.abs() / maxBalance) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _buildOweRow(context, name, amountText, color, progress),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  },
);
}

  Future<List<Map<String, dynamic>>> _resolveNames(List<String> uids) async {
    if (uids.isEmpty) return [];
    return await BackendService.getUsersByIds(uids);
  }

  Widget _buildOweRow(BuildContext context, String name, String amount, Color color, double progress) {
    return CustomCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
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
              Text(
                amount,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  // ---------- Recent Bills ----------
  Widget _buildRecentBills(BuildContext context) {
    final user = BackendService.currentUser;

    if (!BackendService.isFirebaseReady || user == null) {
      return _buildEmptySection(context, 'Recent Bills', 'No recent bills yet');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BackendService.billsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorSection(context, 'Recent Bills', 'Could not load bills');
        }
        if (!snapshot.hasData) {
          return _buildLoadingSection(context, 'Recent Bills');
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _buildEmptySection(context, 'Recent Bills', 'No bills yet');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Bills',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            CustomCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: docs.asMap().entries.map((entry) {
                  final data = entry.value.data();
                  return TweenAnimationBuilder<double>(
                    key: ValueKey(entry.key), // Ensures each item animates when built
                    duration: Duration(milliseconds: 400 + (entry.key * 100)), // Staggered delay
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
                      title: (data['title'] as String?) ?? 'Bill',
                      subtitle: (data['subtitle'] as String?) ?? 'Just now',
                      amount: (data['amountText'] as String?) ?? 'Rs. 0',
                      status: (data['statusText'] as String?) ?? 'Pending',
                      statusColor: BackendService.colorFromValue(
                        data['statusColor'],
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      showDivider: entry.key != docs.length - 1,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBillItem(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
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
                  shape: BoxShape.circle,
                  color: iconBg.withValues(alpha: 0.2), // softer bg
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  Text(
                    status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: statusColor),
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

  // ---------- Bottom Navigation ----------
  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group_outlined),
          activeIcon: Icon(Icons.group),
          label: 'Groups',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'History',
        ),
      ],
    );
  }

  // ---------- Helper Widgets ----------
  Widget _buildLoadingSection(BuildContext context, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySection(BuildContext context, String title, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection(BuildContext context, String title, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ),
      ],
    );
  }
}