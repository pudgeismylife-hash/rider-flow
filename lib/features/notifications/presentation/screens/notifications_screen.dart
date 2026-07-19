import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/notification_service.dart';
import '../../domain/notification_model.dart';

final notificationsListProvider = FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return [];

  final companyId = user.companyId ?? 'co_test';
  final branchId = user.branchId ?? 'br_test';

  final service = ref.read(notificationServiceProvider);
  return service.getNotifications(companyId, branchId);
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _openBroadcastDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161924) : Colors.white,
          title: const Text('Broadcast Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _titleController,
                  labelText: 'Notice Title',
                  prefixIcon: Icons.title_rounded,
                  validator: (val) => val == null || val.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _bodyController,
                  labelText: 'Announcement Details',
                  prefixIcon: Icons.message_outlined,
                  maxLines: 3,
                  validator: (val) => val == null || val.isEmpty ? 'Details are required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(context);
                _sendAnnouncement();
              },
              child: const Text('Send Broadcast', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendAnnouncement() async {
    setState(() => _isSending = true);

    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return;

    final companyId = user.companyId ?? 'co_test';
    final branchId = user.branchId ?? 'br_test';

    final notice = NotificationModel(
      id: '',
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      type: 'general',
      timestamp: DateTime.now(),
    );

    try {
      final service = ref.read(notificationServiceProvider);
      await service.sendNotification(companyId, branchId, notice);
      
      _titleController.clear();
      _bodyController.clear();
      
      ref.invalidate(notificationsListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Broadcast announcement sent to all branch riders.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to broadcast notification: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Board'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined),
            onPressed: () async {
              if (user != null) {
                final service = ref.read(notificationServiceProvider);
                await service.markAllAsRead(user.companyId ?? 'co_test', user.branchId ?? 'br_test');
                ref.invalidate(notificationsListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All notifications marked as read.')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: notificationsAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                title: 'Inbox Clean',
                message: 'No notifications or announcements on this board.',
                icon: Icons.notifications_none_rounded,
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.refresh(notificationsListProvider),
              child: ListView.separated(
                itemCount: list.length,
                padding: const EdgeInsets.all(16),
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notice = list[index];
                  return _buildNotificationTile(context, notice);
                },
              ),
            );
          },
          loading: () => ListView.builder(
            itemCount: 4,
            itemBuilder: (context, index) => const SkeletonListTile(),
          ),
          error: (err, _) => Center(child: Text('Error loading inbox: $err')),
        ),
      ),
      floatingActionButton: user != null && user.role != UserRole.rider
          ? FloatingActionButton(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: Colors.black,
              onPressed: () => _openBroadcastDialog(context),
              child: const Icon(Icons.campaign_rounded),
            )
          : null,
    );
  }

  Widget _buildNotificationTile(BuildContext context, NotificationModel notice) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color = AppTheme.primaryGold;
    IconData icon = Icons.notifications_none_rounded;

    if (notice.type == 'closingReminder') {
      color = AppTheme.errorRed;
      icon = Icons.lock_clock_outlined;
    } else if (notice.type == 'attendanceReminder') {
      color = AppTheme.warningSaffron;
      icon = Icons.how_to_reg_rounded;
    } else if (notice.type == 'advanceAdded') {
      color = AppTheme.infoBlue;
      icon = Icons.add_card_rounded;
    } else if (notice.type == 'paymentReceived') {
      color = AppTheme.successGreen;
      icon = Icons.check_circle_outline_rounded;
    }

    return Card(
      color: notice.isRead 
          ? (isDark ? const Color(0xFF161924) : Colors.white) 
          : (isDark ? const Color(0xFF1B1F30) : AppTheme.primaryGold.withOpacity(0.04)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: notice.isRead 
              ? Colors.transparent 
              : AppTheme.primaryGold.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                notice.title,
                style: TextStyle(
                  fontWeight: notice.isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            if (!notice.isRead)
              const CircleAvatar(radius: 4, backgroundColor: AppTheme.primaryGold),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              notice.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: notice.isRead ? Colors.grey.shade500 : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(notice.timestamp),
              style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
