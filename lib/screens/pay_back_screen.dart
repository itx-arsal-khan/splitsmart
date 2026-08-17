import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/avatar_widget.dart';
import '../utils/snackbar_util.dart';
import 'payment_success_screen.dart';

class PayBackScreen extends StatefulWidget {
  final String toUserUid;
  final String toUser; // Display name
  final double amount;
  final String? initialNote;
  final String groupId;
  final String groupName;
  final bool isPayingOut;

  const PayBackScreen({
    super.key,
    required this.toUserUid,
    required this.toUser,
    required this.amount,
    required this.isPayingOut,
    required this.groupId,
    required this.groupName,
    this.initialNote,
  });

  @override
  State<PayBackScreen> createState() => _PayBackScreenState();
}

class _PayBackScreenState extends State<PayBackScreen> {
  final _noteController = TextEditingController();
  final _customAmountController = TextEditingController();
  bool _isSettling = false;
  bool _isCustomSettle = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialNote != null) {
      _noteController.text = widget.initialNote!;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = BackendService.currentUser;

    if (!BackendService.isFirebaseReady || user == null) {
      return _buildStaticScreen(context);
    }

    return _buildDynamicScreen(context);
  }

  Widget _buildDynamicScreen(BuildContext context) {
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
          widget.isPayingOut ? 'Pay Back' : 'Settle Up',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.lg),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, val, child) {
                return Transform.scale(
                  scale: val,
                  child: Opacity(opacity: val.clamp(0.0, 1.0), child: child),
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: -4,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                      ),
                      child: Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - val)),
                  child: Opacity(opacity: val.clamp(0.0, 1.0), child: child),
                );
              },
              child: Column(
                children: [
                  Text(
                    widget.isPayingOut 
                        ? 'You owe ${widget.toUser}' 
                        : '${widget.toUser} owes you',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Settle All'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Custom Amount'),
                      ),
                    ],
                    selected: {_isCustomSettle},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _isCustomSettle = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (!_isCustomSettle)
                    Text(
                      'Rs. ${widget.amount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: CustomTextField(
                        controller: _customAmountController,
                        hintText: 'Enter amount (max ${widget.amount.toStringAsFixed(0)})',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        prefixText: 'Rs. ',
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add a note',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CustomTextField(
                    controller: _noteController,
                    hintText: 'gave cash, sent on easypaisa',
                    suffixIcon: const Icon(Icons.draw_outlined),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CustomCard(
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: AppRadii.radiusMd,
                            color: Theme.of(context).colorScheme.secondaryContainer,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Method',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Settle this balance directly. This action will clear your debt with ${widget.toUser}.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  CustomButton(
                    text: _isSettling ? 'Processing...' : 'Done — Mark as Paid',
                    type: ButtonType.primary,
                    isLoading: _isSettling,
                    icon: Icons.verified_outlined,
                    onPressed: _settleDebt,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'This will notify ${widget.toUser} about the settlement.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _settleDebt() async {
    final note = _noteController.text.trim();
    
    double settleAmount = widget.amount;
    if (_isCustomSettle) {
      final input = _customAmountController.text.trim();
      if (input.isEmpty) {
        SnackbarUtil.showError(context, 'Please enter an amount');
        return;
      }
      final parsed = double.tryParse(input);
      if (parsed == null || parsed <= 0) {
        SnackbarUtil.showError(context, 'Please enter a valid positive amount');
        return;
      }
      // Assuming floating point inaccuracies might occur, add a small epsilon
      if (parsed > widget.amount + 0.01) {
        SnackbarUtil.showError(context, 'Amount cannot exceed Rs. ${widget.amount.toStringAsFixed(0)}');
        return;
      }
      settleAmount = parsed;
    }

    setState(() => _isSettling = true);

    try {
      await BackendService.settleDebt(
        toUserUid: widget.toUserUid,
        toUserName: widget.toUser,
        amount: settleAmount,
        isPayingOut: widget.isPayingOut,
        note: note.isNotEmpty ? note : 'Settled Up',
        groupId: widget.groupId,
        groupName: widget.groupName,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PaymentSuccessScreen(
            toUser: widget.toUser,
            amount: settleAmount,
          )),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Failed to settle: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSettling = false);
    }
  }

  Widget _buildStaticScreen(BuildContext context) {
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
          'Pay Back',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.onSecondaryContainer),
                ),
                Positioned(
                  bottom: 0,
                  right: -4,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                    child: Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.isPayingOut 
                  ? 'You owe ${widget.toUser}' 
                  : '${widget.toUser} owes you',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Rs. ${widget.amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add a note',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CustomTextField(
              controller: _noteController,
              hintText: 'gave cash, sent on easypaisa',
              suffixIcon: const Icon(Icons.draw_outlined),
            ),
            const SizedBox(height: AppSpacing.lg),
            CustomCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.radiusMd,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Settle this balance directly. This action will clear your debt with ${widget.toUser}.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            CustomButton(
              text: _isSettling ? 'Processing...' : 'Done — Mark as Paid',
              type: ButtonType.primary,
              isLoading: _isSettling,
              icon: Icons.verified_outlined,
              onPressed: _settleDebt,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This will notify ${widget.toUser} about the settlement.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}