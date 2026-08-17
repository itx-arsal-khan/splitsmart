import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/backend_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../utils/snackbar_util.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'payment_success_screen.dart';

class AddBillScreen extends StatefulWidget {
  final String? groupId;
  const AddBillScreen({super.key, this.groupId});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  String _selectedCategory = 'Food';
  String _selectedSplit = 'equally';
  final _descController = TextEditingController();
  final _amountController = TextEditingController(text: '0');
  String? _selectedGroupId; // select by ID
  bool _isSaving = false;

  final Map<String, TextEditingController> _customSplitControllers = {};
  List<Map<String, dynamic>> _groupMembers = [];
  bool _isLoadingMembers = false;

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Food', 'icon': Icons.fastfood},
    {'label': 'Travel', 'icon': Icons.directions_car},
    {'label': 'Trip', 'icon': Icons.flight},
    {'label': 'Utilities', 'icon': Icons.lightbulb_outline},
    {'label': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    for (var c in _customSplitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchGroupMembers(List<String> memberIds) async {
    setState(() => _isLoadingMembers = true);
    try {
      final users = await BackendService.getUsersByIds(memberIds);
      if (!mounted) return;
      setState(() {
        _groupMembers = users;
        for (var u in users) {
          final uid = u['uid'] as String;
          if (!_customSplitControllers.containsKey(uid)) {
            _customSplitControllers[uid] = TextEditingController(text: '0');
          }
        }
      });
    } finally {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  void _onGroupChanged(String? groupId, List<QueryDocumentSnapshot<Map<String, dynamic>>> groupDocs) {
    setState(() => _selectedGroupId = groupId);
    if (groupId != null && _selectedSplit == 'custom') {
      final doc = groupDocs.firstWhere((d) => d.id == groupId);
      final memberIds = List<String>.from(doc.data()['memberIds'] ?? []);
      _fetchGroupMembers(memberIds);
    }
  }

  void _onSplitChanged(String splitType, List<QueryDocumentSnapshot<Map<String, dynamic>>> groupDocs) {
    setState(() => _selectedSplit = splitType);
    if (splitType == 'custom' && _selectedGroupId != null) {
      final doc = groupDocs.firstWhere((d) => d.id == _selectedGroupId);
      final memberIds = List<String>.from(doc.data()['memberIds'] ?? []);
      _fetchGroupMembers(memberIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = BackendService.currentUser;

    if (!BackendService.isFirebaseReady || user == null) {
      return _buildStaticScreen(context);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: BackendService.groupsStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorView(context);
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingView();
          }

          final allDocs = snapshot.data?.docs ?? [];
          final docs = allDocs.where((doc) => doc.data()['createdBy'] == user.uid).toList();
          
          if (docs.isEmpty) {
            return _buildEmptyView(context);
          }

          if (_selectedGroupId == null) {
            final containsWidgetGroupId = docs.any((doc) => doc.id == widget.groupId);
            if (widget.groupId != null && containsWidgetGroupId) {
              _selectedGroupId = widget.groupId;
            } else {
              _selectedGroupId = docs.first.id;
            }
          }

          return _buildForm(context, docs);
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Add a Bill',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> groupDocs,
  ) {
    final docIds = groupDocs.map((doc) => doc.id).toList();
    if (_selectedGroupId != null && !docIds.contains(_selectedGroupId)) {
      _selectedGroupId = docIds.isNotEmpty ? docIds.first : null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          _label('What was it for?'),
          const SizedBox(height: AppSpacing.sm),
          CustomTextField(
            controller: _descController,
            hintText: 'e.g. Chai, Petrol, Lunch',
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Rs.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w300,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _label('Select Category'),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat['label'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['label']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          size: 18,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          cat['label']!,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _label('Which Group?'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: AppRadii.radiusMd,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedGroupId,
                isExpanded: true,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: widget.groupId != null ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                items: groupDocs
                    .map((doc) => DropdownMenuItem(
                          value: doc.id,
                          child: Text((doc.data()['name'] as String?) ?? 'Unnamed Group'),
                        ))
                    .toList(),
                onChanged: widget.groupId != null ? null : (v) => _onGroupChanged(v, groupDocs),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _label('How to Split?'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _splitCard('equally', Icons.group, 'Split Equally', groupDocs),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _splitCard(
                  'custom',
                  Icons.edit_note,
                  'Change\nAmounts',
                  groupDocs
                ),
              ),
            ],
          ),
          _buildCustomSplitUI(),
          const SizedBox(height: 40),
          CustomButton(
            text: _isSaving ? 'Saving...' : 'Save Bill',
            type: ButtonType.primary,
            isLoading: _isSaving,
            icon: Icons.check,
            onPressed: () => _saveBill(context, groupDocs),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _saveBill(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> groupDocs,
  ) async {
    final description = _descController.text.trim();
    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0;

    if (description.isEmpty) {
      SnackbarUtil.showError(context, 'Please enter a description.');
      return;
    }
    if (amount <= 0) {
      SnackbarUtil.showError(context, 'Please enter a valid amount.');
      return;
    }
    if (_selectedGroupId == null || _selectedGroupId!.isEmpty) {
      SnackbarUtil.showError(context, 'Please select a group.');
      return;
    }

    Map<String, double>? customSplits;
    if (_selectedSplit == 'custom') {
      double sum = 0;
      customSplits = {};
      for (var entry in _customSplitControllers.entries) {
        final val = double.tryParse(entry.value.text) ?? 0;
        customSplits[entry.key] = val;
        sum += val;
      }
      if ((sum - amount).abs() > 0.01) {
        SnackbarUtil.showError(context, 'Custom amounts (Rs. $sum) must equal total (Rs. $amount).');
        return;
      }
    }

    final selectedDoc = groupDocs.firstWhere((doc) => doc.id == _selectedGroupId);
    final groupData = selectedDoc.data();
    final groupName = groupData['name'] as String? ?? 'Group';
    final participantIds = List<String>.from(groupData['memberIds'] ?? []);

    setState(() => _isSaving = true);

    try {
      await BackendService.saveBill(
        description: description,
        amount: amount,
        category: _selectedCategory,
        groupId: _selectedGroupId!,
        groupName: groupName,
        splitType: _selectedSplit,
        participantIds: participantIds,
        customSplits: customSplits,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PaymentSuccessScreen(
          isBill: true,
          amount: amount,
          groupName: groupName,
        )),
      );
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Failed to save bill: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _label(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _splitCard(String key, IconData icon, String label, List<QueryDocumentSnapshot<Map<String, dynamic>>> groupDocs) {
    final isSelected = _selectedSplit == key;
    return GestureDetector(
      onTap: () => _onSplitChanged(key, groupDocs),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).cardColor,
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
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSplitUI() {
    if (_selectedSplit != 'custom') return const SizedBox.shrink();
    if (_isLoadingMembers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _label('Custom Amounts'),
        const SizedBox(height: AppSpacing.sm),
        ..._groupMembers.map((member) {
          final uid = member['uid'] as String;
          final name = member['name'] as String? ?? 'Unknown';
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _customSplitControllers[uid],
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.titleMedium,
                    decoration: InputDecoration(
                      prefixText: 'Rs. ',
                      border: OutlineInputBorder(
                        borderRadius: AppRadii.radiusSm,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStaticScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            _label('What was it for?'),
            const SizedBox(height: AppSpacing.sm),
            CustomTextField(
              controller: _descController,
              hintText: 'e.g. Chai, Petrol, Lunch',
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Rs.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w300,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _label('Select Category'),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat['label'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat['label']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 18,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            cat['label']!,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _label('Which Group?'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadii.radiusMd,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: 'Unknown Group',
                  isExpanded: true,
                  style: Theme.of(context).textTheme.titleMedium,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  items: ['Unknown Group']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _label('How to Split?'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _splitCard('equally', Icons.group, 'Split Equally', []),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _splitCard(
                    'custom',
                    Icons.edit_note,
                    'Change\nAmounts',
                    []
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            CustomButton(
              text: _isSaving ? 'Saving...' : 'Save Bill',
              type: ButtonType.primary,
              isLoading: _isSaving,
              icon: Icons.check,
              onPressed: () {
                // For static screen preview
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentSuccessScreen(
                      isBill: true,
                      amount: 0,
                      groupName: 'Preview Group',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No groups available.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You must be a group creator to add bills.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Failed to load groups.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () {
              setState(() {});
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}