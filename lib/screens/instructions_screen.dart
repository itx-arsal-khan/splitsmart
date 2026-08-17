import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          'How to Use SplitSmart',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildInstructionStep(
            context,
            icon: Icons.group_add_outlined,
            title: '1. Create a Group',
            description: 'Start by making a group. Only the person who creates the group can add bills or delete the group. You can add your friends to this group by searching their username or just adding their name.',
          ),
          _buildInstructionStep(
            context,
            icon: Icons.receipt_long_outlined,
            title: '2. Add Bills',
            description: 'As the group creator, tap "Add Bill", select your group, enter the amount, and pick who is involved. The app will automatically split the bill equally among everyone involved.',
          ),
          _buildInstructionStep(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: '3. See Who Owes Who',
            description: 'Check your dashboard or the group details. SplitSmart automatically calculates all the messy math and tells you exactly who owes money to whom.',
          ),
          _buildInstructionStep(
            context,
            icon: Icons.check_circle_outline,
            title: '4. Settle Up',
            description: 'When someone pays you back, tap the "Settle Up" button. You can record the payment to clear their balance and keep everything organized.',
          ),
          _buildInstructionStep(
            context,
            icon: Icons.history,
            title: '5. View History',
            description: 'You can check the history tab anytime to see a timeline of all the bills added and payments settled. Pull down to refresh if needed!',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(BuildContext context, {required IconData icon, required String title, required String description}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
