import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _selectedFilter = 'All';

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();
    bool hasUnread = false;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isRead'] != true && data['read'] != true) {
        hasUnread = true;
        batch.update(doc.reference, {'isRead': true, 'read': true});
      }
    }

    if (hasUnread) {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Color(0xFF00B4D8),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(DocumentReference docRef) async {
    try {
      await docRef.update({'isRead': true, 'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _deleteNotification(DocumentReference docRef) async {
    try {
      await docRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification removed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> _clearAllNotifications(List<QueryDocumentSnapshot> docs) async {
    if (user == null || docs.isEmpty) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      dateTime = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return 'Recently';
    }

    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Stream<List<QueryDocumentSnapshot>> _getNotificationsStream() {
    final uid = user?.uid;
    if (uid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('shop_owners')
        .doc(uid)
        .collection('notifications')
        .snapshots()
        .asyncMap((shopSnap) async {
      final List<QueryDocumentSnapshot> docs = List.from(shopSnap.docs);
      try {
        final deliverySnap = await FirebaseFirestore.instance
            .collection('delivery_partners')
            .doc(uid)
            .collection('notifications')
            .get();
        docs.addAll(deliverySnap.docs);
      } catch (e) {
        debugPrint('Delivery notifications fetch notice: $e');
      }
      try {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .get();
        docs.addAll(userSnap.docs);
      } catch (e) {
        debugPrint('User notifications fetch notice: $e');
      }
      return docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    const navyBlue = Color(0xFF0A1628);
    const primaryBlue = Color(0xFF00B4D8);
    const backgroundWhite = Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: backgroundWhite,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (user != null)
            StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _getNotificationsStream(),
              builder: (context, snapshot) {
                final docs = snapshot.data ?? [];
                if (docs.isEmpty) return const SizedBox.shrink();
                
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'read_all') {
                      _markAllAsRead(docs);
                    } else if (value == 'clear_all') {
                      _clearAllNotifications(docs);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'read_all',
                      child: Row(
                        children: [
                          Icon(Icons.done_all_rounded, size: 18, color: primaryBlue),
                          SizedBox(width: 10),
                          Text('Mark all as read'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text('Clear all'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view notifications'))
          : StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _getNotificationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryBlue));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading notifications: ${snapshot.error}',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  );
                }

                var docs = snapshot.data ?? [];

                // Client side sorting by createdAt descending
                docs = List<QueryDocumentSnapshot>.from(docs)..sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                final int unreadCount = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isRead'] != true && data['read'] != true;
                }).length;

                // Filter logic
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final bool isRead = data['isRead'] == true || data['read'] == true;
                  final String type = (data['type'] ?? '').toString().toLowerCase();

                  if (_selectedFilter == 'Unread') {
                    return !isRead;
                  } else if (_selectedFilter == 'Orders') {
                    return type.contains('order');
                  }
                  return true;
                }).toList();

                return Column(
                  children: [
                    // Top Bar with Filter Chips and Unread Count
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['All', 'Unread', 'Orders'].map((filter) {
                                  final isSelected = _selectedFilter == filter;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ChoiceChip(
                                      label: Text(
                                        filter == 'Unread' && unreadCount > 0
                                            ? 'Unread ($unreadCount)'
                                            : filter,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : navyBlue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      selected: isSelected,
                                      selectedColor: navyBlue,
                                      backgroundColor: Colors.grey.shade100,
                                      showCheckmark: false,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(
                                          color: isSelected ? navyBlue : Colors.grey.shade300,
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedFilter = filter;
                                          });
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            TextButton.icon(
                              onPressed: () => _markAllAsRead(docs),
                              icon: const Icon(Icons.done_all, size: 16, color: primaryBlue),
                              label: const Text(
                                'Mark read',
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Notifications List
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notifications_none_rounded,
                                      size: 56,
                                      color: primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedFilter == 'Unread'
                                        ? 'No unread notifications'
                                        : 'No notifications yet',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Updates on your orders and store activity will appear here.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final bool isRead =
                                    data['isRead'] == true || data['read'] == true;
                                final String title = data['title'] ?? 'Notification';
                                final String body = data['body'] ?? data['message'] ?? '';
                                final String type = (data['type'] ?? '').toString().toLowerCase();
                                final timestamp = data['createdAt'];

                                IconData iconData = Icons.notifications_active_outlined;
                                Color iconColor = primaryBlue;
                                Color iconBg = primaryBlue.withValues(alpha: 0.12);

                                if (type.contains('order')) {
                                  iconData = Icons.shopping_bag_outlined;
                                  iconColor = const Color(0xFF00B4D8);
                                  iconBg = const Color(0xFF00B4D8).withValues(alpha: 0.12);
                                } else if (type.contains('stock') || type.contains('product')) {
                                  iconData = Icons.inventory_2_outlined;
                                  iconColor = const Color(0xFFFF9F43);
                                  iconBg = const Color(0xFFFF9F43).withValues(alpha: 0.12);
                                } else if (type.contains('alert') || type.contains('warning')) {
                                  iconData = Icons.warning_amber_rounded;
                                  iconColor = Colors.redAccent;
                                  iconBg = Colors.redAccent.withValues(alpha: 0.12);
                                }

                                return Dismissible(
                                  key: Key(doc.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.delete_outline, color: Colors.white),
                                  ),
                                  onDismissed: (_) => _deleteNotification(doc.reference),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: isRead ? Colors.white : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isRead
                                            ? const Color(0xFFE2E8F0)
                                            : const Color(0xFF86EFAC),
                                        width: isRead ? 1 : 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _markAsRead(doc.reference),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: iconBg,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(iconData, color: iconColor, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            title,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: isRead
                                                                  ? FontWeight.w600
                                                                  : FontWeight.w800,
                                                              color: const Color(0xFF0F172A),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          _formatTimestamp(timestamp),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey.shade500,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (body.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        body,
                                                        style: TextStyle(
                                                          fontSize: 12.5,
                                                          color: Colors.grey.shade700,
                                                          height: 1.3,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 8, top: 4),
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF10B981),
                                                    shape: BoxShape.circle,
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
                  ],
                );
              },
            ),
    );
  }
}
