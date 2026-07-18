import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../utils/phone_utils.dart';

class BackendService {
  static bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  static FirebaseAuth? get _auth =>
      isFirebaseReady ? FirebaseAuth.instance : null;
  static FirebaseFirestore? get _db =>
      isFirebaseReady ? FirebaseFirestore.instance : null;
  static FirebaseStorage? get _storage => 
      isFirebaseReady ? FirebaseStorage.instance : null;

  static User? get currentUser => _auth?.currentUser;

  static String displayNameForUser(User? user) {
    if (user == null) return 'Guest';
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Guest';
  }

  static String initialsFromName(String? value) {
    final parts = (value ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'SS';
    return parts.take(2).map((part) => part[0]).join().toUpperCase();
  }

  static double numericValue(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          fallback;
    }
    return fallback;
  }

  static Color colorFromValue(dynamic value, Color fallback) {
    if (value is int) return Color(value);
    return fallback;
  }

  static IconData iconFromName(String? value) {
    switch (value) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'wifi':
        return Icons.wifi;
      case 'flight':
        return Icons.flight_takeoff;
      case 'home':
        return Icons.home;
      case 'receipt':
        return Icons.receipt_long;
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      case 'check':
        return Icons.check_circle_outline;
      case 'group':
        return Icons.group;
      case 'person':
        return Icons.person;
      case 'bolt':
        return Icons.bolt;
      case 'shopping_cart':
        return Icons.shopping_cart_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  static Future<void> cleanupCorruptedSettlements() async {
    if (!isFirebaseReady) return;
    try {
      final snapshot = await _db!.collection('bills').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isSettlement'] == true) {
          final settledWith = data['settledWith'] as String?;
          if (settledWith != null && (settledWith.contains(' ') || settledWith.length < 20)) {
            await doc.reference.delete();
            print('Deleted corrupted settlement: ${doc.id}');
          }
        }
      }
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  // ---------- Streams ----------
  static Stream<DocumentSnapshot<Map<String, dynamic>>>? userProfileStream(
    String uid,
  ) {
    if (!isFirebaseReady) return null;
    return _db!.collection('users').doc(uid).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>? groupsStream(String uid) {
    if (!isFirebaseReady) return null;
    return _db!
        .collection('groups')
        .where('memberIds', arrayContains: uid)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>? billsStream(String uid) {
    if (!isFirebaseReady) return null;
    return _db!
        .collection('bills')
        .where('participantIds', arrayContains: uid)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>? activitiesStream(
    String uid,
  ) {
    if (!isFirebaseReady) return null;
    return _db!
        .collection('activities')
        .where('userIds', arrayContains: uid)
        .snapshots();
  }

  // ---------- Unique Constraint Checks ----------
  static Future<bool> checkUsernameAvailable(String username) async {
    if (!isFirebaseReady || username.isEmpty) return false;
    final doc = await _db!.collection('usernames').doc(username).get();
    return !doc.exists;
  }

  static Future<bool> checkPhoneAvailable(String normalizedPhone) async {
    if (!isFirebaseReady || normalizedPhone.isEmpty) return false;
    final doc = await _db!.collection('phoneNumbers').doc(normalizedPhone).get();
    return !doc.exists;
  }

  // ---------- User Profile & Auth ----------
  static Future<UserCredential> signUpUser({
    required String email,
    required String password,
    required String name,
    required String username,
    required String normalizedPhone,
  }) async {
    if (!isFirebaseReady) throw Exception('Firebase is not ready');

    // Check if username or phone exists FIRST (before creating auth)
    // We cannot use a simple check and then auth, because auth creation is async and could race.
    // However, Firestore transactions can't wrap FirebaseAuth calls.
    // Thus, we check first, create Auth user, then transact. If transaction fails, we delete Auth user.

    final db = _db!;
    
    // Preliminary check
    final usernameDoc = await db.collection('usernames').doc(username).get();
    if (usernameDoc.exists) throw Exception('username taken');

    final phoneDoc = await db.collection('phoneNumbers').doc(normalizedPhone).get();
    if (phoneDoc.exists) throw Exception('phone number already registered');

    // Create auth user
    final credential = await _auth!.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    try {
      await db.runTransaction((transaction) async {
        final uDoc = db.collection('usernames').doc(username);
        final pDoc = db.collection('phoneNumbers').doc(normalizedPhone);

        final uSnapshot = await transaction.get(uDoc);
        final pSnapshot = await transaction.get(pDoc);

        if (uSnapshot.exists) {
          throw Exception('username taken');
        }
        if (pSnapshot.exists) {
          throw Exception('phone number already registered');
        }

        // All good, write all 3 docs
        transaction.set(uDoc, {'uid': uid});
        transaction.set(pDoc, {'uid': uid});
        
        final userDoc = db.collection('users').doc(uid);
        transaction.set(userDoc, {
          'uid': uid,
          'name': name.trim(),
          'username': username,
          'phone': normalizedPhone,
          'email': email,
          'photoUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      await credential.user!.updateDisplayName(name.trim());
      
      return credential;
    } catch (e) {
      // If transaction fails, clean up the auth user
      await credential.user?.delete();
      throw e;
    }
  }

  static Future<void> ensureUserProfile(User user, {String? name}) async {
    if (!isFirebaseReady) return;
    await _db!.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name?.trim().isNotEmpty == true
          ? name!.trim()
          : displayNameForUser(user),
      'email': user.email,
      'photoUrl': user.photoURL,
      'createdAt': DateTime.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- Notifications ----------

  static Future<void> _createNotification({
    required String toUserId,
    required String message,
    required String type,
    required String referenceId,
  }) async {
    if (!isFirebaseReady) return;
    if (toUserId == currentUser?.uid) return; // Don't notify yourself

    await _db!.collection('notifications').doc().set({
      'toUserId': toUserId,
      'message': message,
      'read': false,
      'type': type,
      'referenceId': referenceId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>? notificationsStream(String uid) {
    if (!isFirebaseReady) return null;
    return _db!
        .collection('notifications')
        .where('toUserId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    if (!isFirebaseReady) return;
    await _db!.collection('notifications').doc(notificationId).update({'read': true});
  }

  static Future<String> uploadProfilePicture(String uid, Uint8List imageBytes, String fileName) async {
    if (!isFirebaseReady) throw Exception('Firebase not ready');
    
    // We convert the tiny compressed image into a Base64 string.
    // This completely bypasses Firebase Storage, eliminating all upload timeouts, bucket errors, or permissions issues.
    final base64String = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    
    // Update the user document directly in Firestore
    await _db!.collection('users').doc(uid).set({
      'photoUrl': base64String,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    return base64String;
  }

  /// Updates the user's display name in Firebase Auth and Firestore.
  static Future<bool> updateUserDisplayName(String newName) async {
    if (!isFirebaseReady || currentUser == null) return false;
    try {
      await currentUser!.updateDisplayName(newName.trim());
      await _db!.collection('users').doc(currentUser!.uid).update({
        'name': newName.trim(),
        'updatedAt': DateTime.now(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Changes the user's password after re‑authentication.
  static Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (!isFirebaseReady || currentUser == null) return false;
    try {
      final credential = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: currentPassword,
      );
      await currentUser!.reauthenticateWithCredential(credential);
      await currentUser!.updatePassword(newPassword);
      return true;
    } catch (e) {
      return false;
    }
  }


  // ---------- Bill & Group Actions ----------
  static Future<void> saveBill({
    required String description,
    required double amount,
    required String category,
    required String groupId,
    required String groupName,
    required String splitType,
    required List<String> participantIds,
    Map<String, double>? customSplits,
  }) async {
    if (!isFirebaseReady || currentUser == null) return;

    final user = currentUser!;
    final now = DateTime.now();
    final bill = _db!.collection('bills').doc();
    final activity = _db!.collection('activities').doc();

    final iconName = switch (category) {
      'Travel' => 'directions_car',
      'Trip' => 'flight',
      'Utilities' => 'bolt',
      'Other' => 'receipt',
      _ => 'restaurant',
    };

    final actualParticipants = participantIds.contains(user.uid)
        ? participantIds
        : [...participantIds, user.uid];

    await bill.set({
      'title': description,
      'subtitle': '$category • Just now',
      'amountText': 'Rs. ${amount.toStringAsFixed(0)}',
      'amountValue': amount,
      'statusText': splitType == 'custom' ? 'Custom split' : 'Split equally',
      'statusColor': const Color(0xFF59413E).toARGB32(),
      'iconName': iconName,
      'iconBg': const Color(0xFFFFE8CC).toARGB32(),
      'iconColor': const Color(0xFFD97706).toARGB32(),
      'groupId': groupId,
      'groupName': groupName,
      'splitType': splitType,
      'participantIds': actualParticipants,
      if (customSplits != null) 'customSplits': customSplits,
      'createdBy': user.uid,
      'createdByName': displayNameForUser(user),
      'createdAt': now,
    });

    await activity.set({
      'iconName': 'receipt',
      'iconBg': const Color(0xFFFFE8CC).toARGB32(),
      'iconColor': const Color(0xFFD97706).toARGB32(),
      'textParts': ['You added ', description],
      'timeText': 'Just now',
      'amountText': 'Rs. ${amount.toStringAsFixed(0)}',
      'amountColor': const Color(0xFFAE3026).toARGB32(),
      'subText': groupName,
      'subIconName': 'group',
      'userIds': actualParticipants,
      'groupId': groupId,
      'groupName': groupName,
      'createdAt': now,
    });

    final currentUserName = displayNameForUser(user);
    for (final uid in actualParticipants) {
      if (uid != user.uid) {
        await _createNotification(
          toUserId: uid,
          message: "$currentUserName added bill '$description' in '$groupName'",
          type: "bill_added",
          referenceId: bill.id,
        );
      }
    }
  }

  static Future<String?> createGroup({
    required String name,
    required String type,
    required List<String> memberIds,
  }) async {
    if (!isFirebaseReady || currentUser == null) return null;

    final user = currentUser!;
    final now = DateTime.now();
    final groupRef = _db!.collection('groups').doc();

    final isTrip = type == 'Trip';
    final accentColor =
        isTrip ? const Color(0xFFFF6B5B) : const Color(0xFF1CACA4);

    final allMemberIds = memberIds.contains(user.uid) 
        ? memberIds 
        : [...memberIds, user.uid];

    await groupRef.set({
      'name': name,
      'type': type,
      'memberCount': allMemberIds.length,
      'amountText': 'Rs. 0',
      'amountLabel': 'balanced',
      'amountColor': accentColor.toARGB32(),
      'iconName': isTrip ? 'flight' : 'home',
      'memberIds': allMemberIds,
      'createdBy': user.uid,
      'createdAt': now,
      'updatedAt': now,
    });

    final currentUserName = displayNameForUser(user);
    for (final uid in memberIds) {
      if (uid != user.uid) {
        await _createNotification(
          toUserId: uid,
          message: "$currentUserName added you to the group '$name'",
          type: "group_invite",
          referenceId: groupRef.id,
        );
      }
    }

    return groupRef.id;
  }

  static Future<void> settleDebt({
    required String toUserUid,
    required String toUserName,
    required double amount,
    required bool isPayingOut,
    required String note,
    required String groupId,
    required String groupName,
  }) async {
    if (!isFirebaseReady || currentUser == null) return;

    final user = currentUser!;
    final now = DateTime.now();
    final activity = _db!.collection('activities').doc();
    final bill = _db!.collection('bills').doc();

    await bill.set({
      'title': 'Settlement',
      'subtitle': 'Payment • Just now',
      'amountText': 'Rs. ${amount.toStringAsFixed(0)}',
      'amountValue': amount,
      'statusText': 'Settled',
      'statusColor': const Color(0xFF1CACA4).toARGB32(),
      'iconName': 'wallet',
      'iconBg': const Color(0xFFD0F5F3).toARGB32(),
      'iconColor': const Color(0xFF1CACA4).toARGB32(),
      'groupId': groupId,
      'groupName': groupName,
      'splitType': 'settlement',
      'isSettlement': true,
      'isPayingOut': isPayingOut,
      'settledWith': toUserUid,
      'participantIds': [user.uid, toUserUid],
      'createdBy': user.uid,
      'createdByName': displayNameForUser(user),
      'createdAt': now,
    });

    await activity.set({
      'iconName': 'wallet',
      'iconBg': const Color(0xFFD0F5F3).toARGB32(),
      'iconColor': const Color(0xFF1CACA4).toARGB32(),
      'textParts': ['You settled ', 'with $toUserName'],
      'timeText': 'Just now',
      'amountText': 'Rs. ${amount.toStringAsFixed(0)}',
      'amountColor': const Color(0xFF1CACA4).toARGB32(),
      'subText': note.isNotEmpty ? note : 'Settled Up',
      'subIconName': 'check',
      'userIds': [user.uid, toUserUid],
      'groupId': groupId,
      'groupName': groupName,
      'createdAt': now,
    });

    final currentUserName = displayNameForUser(user);
    await _createNotification(
      toUserId: toUserUid,
      message: "$currentUserName settled Rs. ${amount.toStringAsFixed(0)} with you in '$groupName'",
      type: "settlement",
      referenceId: groupId,
    );
  }

  // ---------- Group & Bill Streams ----------
  static Stream<DocumentSnapshot<Map<String, dynamic>>>? groupStream(
    String groupId,
  ) {
    if (!isFirebaseReady) return null;
    return _db!.collection('groups').doc(groupId).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>? billsForGroupStream(
    String groupId,
  ) {
    if (!isFirebaseReady) return null;
    return _db!
        .collection('bills')
        .where('groupId', isEqualTo: groupId)
        .snapshots();
  }

  /// Returns a stream of balance data for a specific group.
  /// The stream emits a map containing:
  /// - totalOwedToUser: double
  /// - totalUserOwes: double
  /// - balances: Map<String, double> (uid -> net balance)
  static Stream<Map<String, dynamic>>? groupBalanceStream(String groupId, String uid) {
    if (!isFirebaseReady) return null;

    return _db!
        .collection('bills')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
      double totalOwedToUser = 0;
      double totalUserOwes = 0;
      Map<String, double> balances = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amountValue'] as num?)?.toDouble() ?? 0;
        final participants = List<String>.from(data['participantIds'] ?? []);
        final creator = data['createdBy'] as String?;
        final isSettlement = data['isSettlement'] == true;

        if (participants.isEmpty || amount == 0) continue;

        if (isSettlement) {
          final settledWith = data['settledWith'] as String?;
          // If isPayingOut is true, the creator is sending money to settledWith.
          // If false, the creator is receiving money from settledWith.
          // For backward compatibility with old test data, default to false.
          final isPayingOut = data['isPayingOut'] as bool? ?? false;

          if (creator == uid && settledWith != null) {
            if (isPayingOut) {
              balances[settledWith] = (balances[settledWith] ?? 0) + amount;
              totalOwedToUser += amount;
            } else {
              balances[settledWith] = (balances[settledWith] ?? 0) - amount;
              totalUserOwes += amount;
            }
          } else if (settledWith == uid && creator != null) {
            if (isPayingOut) {
              balances[creator] = (balances[creator] ?? 0) - amount;
              totalUserOwes += amount;
            } else {
              balances[creator] = (balances[creator] ?? 0) + amount;
              totalOwedToUser += amount;
            }
          }
          continue;
        }

        final splitType = data['splitType'] as String?;
        final customSplitsMap = data['customSplits'] as Map<String, dynamic>?;

        if (creator == uid) {
          // User paid the bill – others owe them
          for (final p in participants) {
            if (p != uid) {
              double share = (splitType == 'custom' && customSplitsMap != null)
                  ? (customSplitsMap[p] as num?)?.toDouble() ?? 0.0
                  : amount / participants.length;
              balances[p] = (balances[p] ?? 0) + share;
              totalOwedToUser += share;
            }
          }
        } else if (creator != null && participants.contains(uid)) {
          // Someone else paid – user owes their share
          double share = (splitType == 'custom' && customSplitsMap != null)
              ? (customSplitsMap[uid] as num?)?.toDouble() ?? 0.0
              : amount / participants.length;
          balances[creator] = (balances[creator] ?? 0) - share;
          totalUserOwes += share;
        }
      }

      return {
        'totalOwedToUser': totalOwedToUser,
        'totalUserOwes': totalUserOwes,
        'balances': balances,
        'hasBills': snapshot.docs.isNotEmpty,
      };
    });
  }

  /// Fetches user profiles for a list of UIDs.
  static Future<List<Map<String, dynamic>>> getUsersByIds(
    List<String> uids,
  ) async {
    if (!isFirebaseReady || uids.isEmpty) return [];
    final snapshot = await _db!
        .collection('users')
        .where(FieldPath.documentId, whereIn: uids)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ---------- Group & Member Management ----------

  /// Deletes a group document and all its associated bills and activities.
  static Future<void> deleteGroup(String groupId) async {
    if (!isFirebaseReady) return;
    
    // 1. Delete all bills associated with this group
    final billsSnapshot = await _db!.collection('bills').where('groupId', isEqualTo: groupId).get();
    for (var doc in billsSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // 2. Delete all activities associated with this group
    final activitiesSnapshot = await _db!.collection('activities').where('groupId', isEqualTo: groupId).get();
    for (var doc in activitiesSnapshot.docs) {
      await doc.reference.delete();
    }

    // 3. Delete the group itself
    await _db!.collection('groups').doc(groupId).delete();
  }

  /// Cleans up orphaned bills and activities from groups that no longer exist.
  static Future<void> cleanupOrphanedData() async {
    if (!isFirebaseReady) return;
    try {
      // 1. Get all active group IDs
      final groupsSnapshot = await _db!.collection('groups').get();
      final activeGroupIds = groupsSnapshot.docs.map((d) => d.id).toSet();

      // 2. Delete orphaned bills
      final billsSnapshot = await _db!.collection('bills').get();
      int billsDeleted = 0;
      for (var doc in billsSnapshot.docs) {
        final groupId = doc.data()['groupId'] as String?;
        if (groupId != null && !activeGroupIds.contains(groupId)) {
          await doc.reference.delete();
          billsDeleted++;
        }
      }

      // 3. Delete orphaned activities
      final activitiesSnapshot = await _db!.collection('activities').get();
      int activitiesDeleted = 0;
      for (var doc in activitiesSnapshot.docs) {
        final groupId = doc.data()['groupId'] as String?;
        if (groupId != null && !activeGroupIds.contains(groupId)) {
          await doc.reference.delete();
          activitiesDeleted++;
        }
      }
      print('Cleanup complete: Deleted $billsDeleted orphaned bills and $activitiesDeleted orphaned activities.');
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  /// Removes a member from a group.
  static Future<void> removeMemberFromGroup(String groupId, String memberUid) async {
    if (!isFirebaseReady) return;
    final groupRef = _db!.collection('groups').doc(groupId);
    await groupRef.update({
      'memberIds': FieldValue.arrayRemove([memberUid]),
    });
    // Decrement member count
    await groupRef.update({
      'memberCount': FieldValue.increment(-1),
    });
  }

  /// Adds a member to a group.
  static Future<void> addMemberToGroup(String groupId, String memberUid) async {
    if (!isFirebaseReady) return;
    final groupRef = _db!.collection('groups').doc(groupId);
    await groupRef.update({
      'memberIds': FieldValue.arrayUnion([memberUid]),
    });
    // Increment member count
    await groupRef.update({
      'memberCount': FieldValue.increment(1),
    });

    if (currentUser != null && currentUser!.uid != memberUid) {
      final doc = await groupRef.get();
      if (doc.exists) {
        final groupName = doc.data()?['name'] ?? 'Group';
        final currentUserName = displayNameForUser(currentUser!);
        await _createNotification(
          toUserId: memberUid,
          message: "$currentUserName added you to the group '$groupName'",
          type: "group_invite",
          referenceId: groupId,
        );
      }
    }
  }

  /// Searches for users by name (prefix, case‑insensitive) – returns list of user maps.
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (!isFirebaseReady || query.trim().isEmpty) return [];
    final search = query.trim();
    final end = search + '\uf8ff';
    final snapshot = await _db!
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: search)
        .where('name', isLessThanOrEqualTo: end)
        .limit(10)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ---------- Create a new user with only a name ----------
  static Future<Map<String, dynamic>?> searchUserByPhoneOrUsername(String input) async {
    if (!isFirebaseReady || input.trim().isEmpty) return null;
    final query = input.trim();
    
    // Check if it looks like a phone number (contains digits/plus)
    final isPhone = RegExp(r'^[\+\d\s]+$').hasMatch(query);
    
    String uid;
    
    if (isPhone) {
      final normalized = PhoneUtils.normalizePhone(query);
      final doc = await _db!.collection('phoneNumbers').doc(normalized).get();
      if (!doc.exists) return null;
      uid = doc.data()!['uid'] as String;
    } else {
      final username = query.toLowerCase();
      final doc = await _db!.collection('usernames').doc(username).get();
      if (!doc.exists) return null;
      uid = doc.data()!['uid'] as String;
    }
    
    final userDoc = await _db!.collection('users').doc(uid).get();
    return userDoc.exists ? userDoc.data() : null;
  }

  /// Creates a new user document with the given name and returns the generated UID.
  static Future<String> createUserWithName(String name) async {
    if (!isFirebaseReady) return '';
    final ref = _db!.collection('users').doc(); // auto‑generate UID
    final uid = ref.id;
    await ref.set({
      'uid': uid,
      'name': name.trim(),
      'email': '', // optional
      'photoUrl': null,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    return uid;
  }

  // ---------- Real Balance Computation ----------
  /// Returns a stream of balance data for the given user.
  /// The stream emits a map containing:
  /// - totalOwedToUser: double (total others owe the user)
  /// - totalUserOwes: double (total user owes others)
  /// - netBalance: double (totalOwedToUser - totalUserOwes)
  /// - balances: Map<String, double> (uid -> net balance: positive means owes user)
  static Stream<Map<String, dynamic>>? userBalanceStream(String uid) {
    if (!isFirebaseReady) return null;

    return _db!
        .collection('bills')
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      double totalOwedToUser = 0;
      double totalUserOwes = 0;
      Map<String, double> balances = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amountValue'] as num?)?.toDouble() ?? 0;
        final participants = List<String>.from(data['participantIds'] ?? []);
        final creator = data['createdBy'] as String?;
        final isSettlement = data['isSettlement'] == true;

        if (participants.isEmpty || amount == 0) continue;

        if (isSettlement) {
          final settledWith = data['settledWith'] as String?;
          final isPayingOut = data['isPayingOut'] as bool? ?? false;

          if (creator == uid && settledWith != null) {
            if (isPayingOut) {
              balances[settledWith] = (balances[settledWith] ?? 0) + amount;
              totalOwedToUser += amount;
            } else {
              balances[settledWith] = (balances[settledWith] ?? 0) - amount;
              totalUserOwes += amount;
            }
          } else if (settledWith == uid && creator != null) {
            if (isPayingOut) {
              balances[creator] = (balances[creator] ?? 0) - amount;
              totalUserOwes += amount;
            } else {
              balances[creator] = (balances[creator] ?? 0) + amount;
              totalOwedToUser += amount;
            }
          }
          continue;
        }

        final splitType = data['splitType'] as String?;
        final customSplitsMap = data['customSplits'] as Map<String, dynamic>?;

        if (creator == uid) {
          // User paid the bill – others owe them
          double userOwnShare = (splitType == 'custom' && customSplitsMap != null)
              ? (customSplitsMap[uid] as num?)?.toDouble() ?? 0.0
              : amount / participants.length;
          
          totalOwedToUser += amount - userOwnShare;
          for (final p in participants) {
            if (p != uid) {
              double share = (splitType == 'custom' && customSplitsMap != null)
                  ? (customSplitsMap[p] as num?)?.toDouble() ?? 0.0
                  : amount / participants.length;
              balances[p] = (balances[p] ?? 0) + share;
            }
          }
        } else if (creator != null) {
          // Someone else paid – user owes their share
          double share = (splitType == 'custom' && customSplitsMap != null)
              ? (customSplitsMap[uid] as num?)?.toDouble() ?? 0.0
              : amount / participants.length;
          totalUserOwes += share;
          balances[creator] = (balances[creator] ?? 0) - share;
        }
      }

      return {
        'totalOwedToUser': totalOwedToUser,
        'totalUserOwes': totalUserOwes,
        'netBalance': totalOwedToUser - totalUserOwes,
        'balances': balances, // uid -> net balance (positive = owes user)
      };
    });
  }
}