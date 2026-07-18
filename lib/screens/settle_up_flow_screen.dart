import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/backend_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import 'pay_back_screen.dart';

class SettleUpGroupsScreen extends StatefulWidget {
  const SettleUpGroupsScreen({super.key});

  @override
  State<SettleUpGroupsScreen> createState() => _SettleUpGroupsScreenState();
}

class _SettleUpGroupsScreenState extends State<SettleUpGroupsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = BackendService.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text('Select Group', style: Theme.of(context).textTheme.headlineMedium),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: (!BackendService.isFirebaseReady || user == null)
          ? const Center(child: Text('Firebase not ready'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: BackendService.groupsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading groups'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data?.docs ?? [];
                docs = docs.where((doc) {
                  final createdBy = doc.data()['createdBy'] as String?;
                  return createdBy == null || createdBy == user.uid;
                }).toList();
                
                if (docs.isEmpty) {
                  return Center(
                    child: Text('No groups found', style: Theme.of(context).textTheme.bodyLarge),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final groupId = doc.id;
                    final groupName = (data['name'] as String?) ?? 'Group';
                    final accent = BackendService.colorFromValue(
                      data['amountColor'],
                      Theme.of(context).colorScheme.secondary,
                    );
                    final isTrip = data['iconName'] == 'flight';

                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutBack,
                      builder: (context, val, child) {
                        return Transform.translate(
                          offset: Offset(0, 50 * (1 - val)),
                          child: Opacity(
                            opacity: val.clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: CustomCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: () {
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
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: AppRadii.radiusMd,
                                color: accent.withValues(alpha: 0.15),
                              ),
                              child: Icon(
                                isTrip ? Icons.flight_takeoff : Icons.home,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                groupName,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class SettleUpMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const SettleUpMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<SettleUpMembersScreen> createState() => _SettleUpMembersScreenState();
}

class _SettleUpMembersScreenState extends State<SettleUpMembersScreen> {
  String? _selectedUid;
  String? _selectedName;
  double _selectedAmount = 0;
  bool _selectedIsPayingOut = false;

  @override
  Widget build(BuildContext context) {
    final uid = BackendService.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text('Select Member', style: Theme.of(context).textTheme.headlineMedium),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('User not found'))
          : StreamBuilder<Map<String, dynamic>>(
              stream: BackendService.groupBalanceStream(widget.groupId, uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading balances'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!;
                final balances = data['balances'] as Map<String, double>? ?? {};
                final sorted = balances.entries
                    .where((e) => e.value.abs() > 0.01)
                    .toList()
                  ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

                if (sorted.isEmpty) {
                  return Center(
                    child: Text('All settled up in this group!', style: Theme.of(context).textTheme.bodyLarge),
                  );
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: BackendService.getUsersByIds(sorted.map((e) => e.key).toList()),
                  builder: (context, nameSnapshot) {
                    final nameMap = nameSnapshot.data ?? [];

                    return Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: sorted.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                            itemBuilder: (context, index) {
                              final entry = sorted[index];
                              final targetUid = entry.key;
                              final balance = entry.value;
                              final targetUserData = nameMap.firstWhere(
                                (u) => u['uid'] == targetUid,
                                orElse: () => {'name': 'Someone'},
                              );
                              final name = targetUserData['name'] as String? ?? 'Someone';
                              final isPositive = balance > 0;
                              final amountText = isPositive
                                  ? 'owes you Rs. ${balance.toStringAsFixed(0)}'
                                  : 'you owe Rs. ${balance.abs().toStringAsFixed(0)}';
                              final color = isPositive
                                  ? Theme.of(context).colorScheme.secondary
                                  : Theme.of(context).colorScheme.error;

                              final isSelected = _selectedUid == targetUid;

                              return TweenAnimationBuilder<double>(
                                duration: Duration(milliseconds: 300 + (index * 100)),
                                tween: Tween(begin: 0.0, end: 1.0),
                                curve: Curves.easeOutBack,
                                builder: (context, val, child) {
                                  return Transform.translate(
                                    offset: Offset(30 * (1 - val), 0),
                                    child: Opacity(
                                      opacity: val.clamp(0.0, 1.0),
                                      child: child,
                                    ),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: AppRadii.radiusLg,
                                    border: Border.all(
                                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected ? [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      )
                                    ] : null,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: AppRadii.radiusLg,
                                      onTap: () {
                                        setState(() {
                                          _selectedUid = targetUid;
                                          _selectedName = name;
                                          _selectedAmount = balance.abs();
                                          _selectedIsPayingOut = !isPositive;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(AppSpacing.md),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                                                  width: 2,
                                                ),
                                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                              ),
                                              child: isSelected
                                                  ? Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.onPrimary)
                                                  : null,
                                            ),
                                            const SizedBox(width: AppSpacing.md),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis,),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    amountText,
                                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: color,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: CustomButton(
                            text: 'Settle Up',
                            type: ButtonType.primary,
                            onPressed: _selectedUid == null
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PayBackScreen(
                                          toUserUid: _selectedUid!,
                                          toUser: _selectedName!,
                                          amount: _selectedAmount,
                                          isPayingOut: _selectedIsPayingOut,
                                          groupId: widget.groupId,
                                          groupName: widget.groupName,
                                        ),
                                      ),
                                    );
                                  },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}
