import 'dart:async';
import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/avatar_widget.dart';
import '../utils/snackbar_util.dart';
import 'group_detail_screen.dart';

class MakeGroupScreen extends StatefulWidget {
  const MakeGroupScreen({super.key});

  @override
  State<MakeGroupScreen> createState() => _MakeGroupScreenState();
}

class _MakeGroupScreenState extends State<MakeGroupScreen> {
  String _selectedType = 'Trip';
  final Set<String> _selectedFriendUids = {};
  final Map<String, Map<String, dynamic>> _friendMap = {};
  final _groupNameController = TextEditingController();
  bool _isCreating = false;
  bool _loadingRecent = true;
  List<Map<String, dynamic>> _recentFriends = [];

  final List<Map<String, dynamic>> _types = [
    {'label': 'Trip', 'icon': Icons.flight},
    {'label': 'Roommates', 'icon': Icons.home},
    {'label': 'Event', 'icon': Icons.celebration},
    {'label': 'Just Two of Us', 'icon': Icons.people},
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentFriends();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentFriends() async {
    final user = BackendService.currentUser;
    if (user == null) {
      setState(() => _loadingRecent = false);
      return;
    }

    setState(() => _loadingRecent = true);

    try {
      final groupsSnapshot = await BackendService.groupsStream(user.uid)?.first;
      if (groupsSnapshot == null) {
        setState(() => _loadingRecent = false);
        return;
      }

      final allMemberIds = <String>{};
      for (final doc in groupsSnapshot.docs) {
        final data = doc.data();
        final ids = List<String>.from(data['memberIds'] ?? []);
        allMemberIds.addAll(ids);
      }
      allMemberIds.remove(user.uid);

      if (allMemberIds.isNotEmpty) {
        final users = await BackendService.getUsersByIds(allMemberIds.toList());
        setState(() {
          _recentFriends = users;
          for (final user in users) {
            final uid = user['uid'] as String?;
            if (uid != null) {
              _friendMap[uid] = user;
            }
          }
          _loadingRecent = false;
        });
      } else {
        setState(() => _loadingRecent = false);
      }
    } catch (e) {
      setState(() => _loadingRecent = false);
    }
  }

  void _showAddFriendDialog() {
    final TextEditingController searchController = TextEditingController();
    Map<String, dynamic>? searchedUser;
    bool hasSearched = false;
    bool isSearching = false;
    Timer? debounce;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Add New Friend',
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: searchController,
                  hintText: "Enter username or phone",
                  prefixIcon: Icons.search,
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
                const SizedBox(height: AppSpacing.sm),
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
                      final isAlreadyAdded = _selectedFriendUids.contains(uid);

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
                                    onPressed: () {
                                      if (uid == null) return;
                                      this.setState(() {
                                        _selectedFriendUids.add(uid);
                                        _friendMap[uid] = {
                                          'uid': uid, 
                                          'name': name, 
                                          'email': searchedUser!['email'] ?? '',
                                          'username': username,
                                        };
                                        if (!_recentFriends.any((f) => f['uid'] == uid)) {
                                          _recentFriends.add(_friendMap[uid]!);
                                        }
                                      });
                                      Navigator.pop(ctx);
                                      SnackbarUtil.showSuccess(context, '$name added to group list');
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

  Future<void> _addFriend(BuildContext context, String name, VoidCallback setLoading, VoidCallback clearLoading) async {
    if (name.isEmpty) return;

    FocusScope.of(context).unfocus();
    setLoading();

    try {
      final uid = await BackendService.createUserWithName(name);
      if (uid.isEmpty) throw Exception('Failed to create user');

      setState(() {
        _selectedFriendUids.add(uid);
        _friendMap[uid] = {'uid': uid, 'name': name, 'email': ''};
        if (!_recentFriends.any((f) => f['uid'] == uid)) {
          _recentFriends.add({'uid': uid, 'name': name, 'email': ''});
        }
      });

      Navigator.pop(context);
      SnackbarUtil.showSuccess(context, '$name added to group');
    } catch (e) {
      SnackbarUtil.showError(context, 'Failed to add: ${e.toString()}');
    } finally {
      clearLoading();
    }
  }

  void _toggleFriend(String uid) {
    setState(() {
      if (_selectedFriendUids.contains(uid)) {
        _selectedFriendUids.remove(uid);
      } else {
        _selectedFriendUids.add(uid);
      }
    });
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      SnackbarUtil.showError(context, 'Please enter a group name.');
      return;
    }

    if (_selectedFriendUids.isEmpty) {
      SnackbarUtil.showError(context, 'Please select at least one friend.');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final groupId = await BackendService.createGroup(
        name: name,
        type: _selectedType,
        memberIds: _selectedFriendUids.toList(),
      );

      if (groupId == null) throw Exception('Failed to create group.');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Widget _friendTile(String uid, String name, String email, bool selected) {
    return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).cardColor,
          borderRadius: AppRadii.radiusMd,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
        children: [
          AvatarWidget(
            initials: BackendService.initialsFromName(name),
            size: 40,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            textColor: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleFriend(uid),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 16)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedFriendUids.length;

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
          'Make a Group',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(
              'Group Name',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CustomTextField(
              controller: _groupNameController,
              hintText: 'e.g. Weekend Trip',
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'What Kind of Group?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.0,
              children: _types.map((t) {
                final isSelected = _selectedType == t['label'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t['label']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                          : Theme.of(context).cardColor,
                      borderRadius: AppRadii.radiusMd,
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          t['icon'] as IconData,
                          size: 28,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t['label']!,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  'Select Friends',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  children: [
                    Text(
                      '$selectedCount Selected',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddFriendDialog,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Add New'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.radiusLg,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loadingRecent)
              const Center(child: CircularProgressIndicator())
            else if (_recentFriends.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No recent friends found.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use "Add New" to add friends.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._recentFriends.asMap().entries.map((entry) {
                final friend = entry.value;
                final uid = friend['uid'] as String?;
                if (uid == null) return const SizedBox.shrink();
                final name = friend['name'] as String? ?? 'Unknown';
                final email = friend['email'] as String? ?? '';
                final isSelected = _selectedFriendUids.contains(uid);
                
                return TweenAnimationBuilder<double>(
                  key: ValueKey(uid),
                  duration: Duration(milliseconds: 400 + (entry.key * 100)),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutQuart,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(20 * (1 - value), 0),
                        child: child,
                      ),
                    );
                  },
                  child: _friendTile(uid, name, email, isSelected),
                );
              }),
            const SizedBox(height: AppSpacing.xl),
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: AppRadii.radiusLg,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Split expenses easily.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage group budgets without the headache.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            CustomButton(
              text: _isCreating ? 'Creating...' : 'Create Group',
              type: ButtonType.primary,
              isLoading: _isCreating,
              onPressed: _createGroup,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}