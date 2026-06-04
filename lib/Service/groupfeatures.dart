import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Service/encryption.dart';
import 'chatfeature.dart';

class GroupFeatures {
  /// Create a new group
  static Future<String> createGroup({
    required String groupName,
    required List<String> memberIds,
    String? groupIcon,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc();
      final groupId = groupRef.id;

      // Add creator to members list
      if (!memberIds.contains(currentUser.uid)) {
        memberIds.add(currentUser.uid);
      }

      // Get usernames for all members
      Map<String, String> memberUsernames = {};
      for (String uid in memberIds) {
        memberUsernames[uid] = await ChatFeatures.getUsername(uid);
      }

      final groupData = {
        'groupId': groupId,
        'groupName': groupName,
        'groupIcon': groupIcon,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'members': memberIds,
        'memberUsernames': memberUsernames,
        'admins': [currentUser.uid], // Creator is admin
        'description': '',
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      };

      await groupRef.set(groupData);

      // Send system message about group creation
      await _sendSystemMessage(
        groupId: groupId,
        message: '${memberUsernames[currentUser.uid]} created this group',
        type: 'group_created',
      );

      return groupId;
    } catch (e) {
      print('❌ Error creating group: $e');
      throw Exception("Failed to create group. Please try again.");
    }
  }

  /// Get group information
  static Future<Map<String, dynamic>?> getGroupInfo(String groupId) async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();

      if (groupDoc.exists) {
        return groupDoc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting group info: $e');
      return null;
    }
  }

  /// Add member to group
  static Future<void> addMember({
    required String groupId,
    required String newMemberUid,
    required String currentUserUid,
  }) async {
    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      final groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }

      final groupData = groupDoc.data()!;
      final admins = List<String>.from(groupData['admins'] ?? []);
      final createdBy = groupData['createdBy'];

      // Check if current user is admin or creator
      if (!admins.contains(currentUserUid) && currentUserUid != createdBy) {
        throw Exception("Only admins can add members");
      }

      final members = List<String>.from(groupData['members'] ?? []);

      if (members.contains(newMemberUid)) {
        throw Exception("User is already a member");
      }

      // Add member
      members.add(newMemberUid);

      // Update member usernames
      final memberUsernames = Map<String, String>.from(groupData['memberUsernames'] ?? {});
      memberUsernames[newMemberUid] = await ChatFeatures.getUsername(newMemberUid);

      await groupRef.update({
        'members': members,
        'memberUsernames': memberUsernames,
      });

      // Send system message
      final adderName = await ChatFeatures.getUsername(currentUserUid);
      final addedName = await ChatFeatures.getUsername(newMemberUid);
      await _sendSystemMessage(
        groupId: groupId,
        message: '$adderName added $addedName',
        type: 'member_added',
      );
    } catch (e) {
      print('❌ Error adding member: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Remove member from group
  static Future<void> removeMember({
    required String groupId,
    required String memberUid,
    required String currentUserUid,
  }) async {
    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      final groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }

      final groupData = groupDoc.data()!;
      final admins = List<String>.from(groupData['admins'] ?? []);
      final members = List<String>.from(groupData['members'] ?? []);
      final createdBy = groupData['createdBy'];

      // Check permissions: allow admins or the creator (except for removing themselves)
      if (!admins.contains(currentUserUid) && currentUserUid != createdBy && currentUserUid != memberUid) {
        throw Exception("Only admins or the group creator can remove members");
      }
      if (currentUserUid == memberUid && currentUserUid != createdBy) {
        // Only allow self-removal if not the creator (creator can remove themselves via delete group)
        throw Exception("You cannot remove yourself from the group as creator. Use delete group instead.");
      }

      if (!members.contains(memberUid)) {
        throw Exception("User is not a member");
      }

      // Remove member
      members.remove(memberUid);

      // Remove from admins if they were admin
      if (admins.contains(memberUid)) {
        admins.remove(memberUid);
      }

      // Update member usernames
      final memberUsernames = Map<String, String>.from(groupData['memberUsernames'] ?? {});
      memberUsernames.remove(memberUid);

      await groupRef.update({
        'members': members,
        'admins': admins,
        'memberUsernames': memberUsernames,
      });

      // Send system message
      final removerName = await ChatFeatures.getUsername(currentUserUid);
      final removedName = await ChatFeatures.getUsername(memberUid);

      String message;
      if (currentUserUid == memberUid) {
        message = '$removedName left the group';
      } else {
        message = '$removerName removed $removedName';
      }

      await _sendSystemMessage(
        groupId: groupId,
        message: message,
        type: currentUserUid == memberUid ? 'member_left' : 'member_removed',
      );
    } catch (e) {
      print('❌ Error removing member: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Make user admin
  static Future<void> makeAdmin({
    required String groupId,
    required String memberUid,
    required String currentUserUid,
  }) async {
    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      final groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }

      final groupData = groupDoc.data()!;
      final admins = List<String>.from(groupData['admins'] ?? []);
      final members = List<String>.from(groupData['members'] ?? []);

      // Check if current user is admin
      if (!admins.contains(currentUserUid)) {
        throw Exception("Only admins can make other users admin");
      }

      if (!members.contains(memberUid)) {
        throw Exception("User is not a member");
      }

      if (admins.contains(memberUid)) {
        throw Exception("User is already an admin");
      }

      admins.add(memberUid);

      await groupRef.update({
        'admins': admins,
      });

      // Send system message
      final promoterName = await ChatFeatures.getUsername(currentUserUid);
      final promotedName = await ChatFeatures.getUsername(memberUid);
      await _sendSystemMessage(
        groupId: groupId,
        message: '$promoterName made $promotedName an admin',
        type: 'admin_added',
      );
    } catch (e) {
      print('❌ Error making admin: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Remove admin privileges
  static Future<void> removeAdmin({
    required String groupId,
    required String adminUid,
    required String currentUserUid,
  }) async {
    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      final groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }

      final groupData = groupDoc.data()!;
      final admins = List<String>.from(groupData['admins'] ?? []);

      // Check if current user is admin
      if (!admins.contains(currentUserUid)) {
        throw Exception("Only admins can remove admin privileges");
      }

      if (!admins.contains(adminUid)) {
        throw Exception("User is not an admin");
      }

      // Ensure at least one admin remains
      if (admins.length <= 1) {
        throw Exception("At least one admin must remain");
      }

      admins.remove(adminUid);

      await groupRef.update({
        'admins': admins,
      });

      // Send system message
      final removerName = await ChatFeatures.getUsername(currentUserUid);
      final removedName = await ChatFeatures.getUsername(adminUid);
      await _sendSystemMessage(
        groupId: groupId,
        message: '$removerName removed $removedName as admin',
        type: 'admin_removed',
      );
    } catch (e) {
      print('❌ Error removing admin: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update group name
  static Future<void> updateGroupName({
    required String groupId,
    required String newName,
    required String currentUserUid,
  }) async {
    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      final groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }

      final groupData = groupDoc.data()!;
      final admins = List<String>.from(groupData['admins'] ?? []);

      // Check if current user is admin
      if (!admins.contains(currentUserUid)) {
        throw Exception("Only admins can change group name");
      }

      final oldName = groupData['groupName'];

      await groupRef.update({
        'groupName': newName,
      });

      // Send system message
      final changerName = await ChatFeatures.getUsername(currentUserUid);
      await _sendSystemMessage(
        groupId: groupId,
        message: '$changerName changed group name from "$oldName" to "$newName"',
        type: 'name_changed',
      );
    } catch (e) {
      print('❌ Error updating group name: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update group description
  static Future<void> updateGroupDescription({
    required String groupId,
    required String newDescription,
    required String currentUserUid,
  }) async {
    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      final groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }

      final groupData = groupDoc.data()!;
      final admins = List<String>.from(groupData['admins'] ?? []);

      // Check if current user is admin
      if (!admins.contains(currentUserUid)) {
        throw Exception("Only admins can change group description");
      }

      await groupRef.update({
        'description': newDescription,
      });
    } catch (e) {
      print('❌ Error updating group description: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Mute/unmute group notifications for user
  static Future<void> toggleMuteNotifications({
    required String groupId,
    required String userId,
    required bool mute,
  }) async {
    try {
      final userGroupRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groupSettings')
          .doc(groupId);

      await userGroupRef.set({
        'muteNotifications': mute,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error toggling mute: $e');
      throw Exception("Failed to update notification settings");
    }
  }

  /// Get mute status for user in group
  static Future<bool> getMuteStatus({
    required String groupId,
    required String userId,
  }) async {
    try {
      final userGroupDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groupSettings')
          .doc(groupId)
          .get();

      if (userGroupDoc.exists) {
        return userGroupDoc.data()?['muteNotifications'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error getting mute status: $e');
      return false;
    }
  }

  /// Check if user is admin
  static Future<bool> isAdmin({
    required String groupId,
    required String userId,
  }) async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();

      if (groupDoc.exists) {
        final admins = List<String>.from(groupDoc.data()?['admins'] ?? []);
        return admins.contains(userId);
      }
      return false;
    } catch (e) {
      print('❌ Error checking admin status: $e');
      return false;
    }
  }

  /// Send system message
  static Future<void> _sendSystemMessage({
    required String groupId,
    required String message,
    required String type,
  }) async {
    try {
      final chatRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('messages');

      await chatRef.add({
        'message': message,
        'type': 'system',
        'systemType': type,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error sending system message: $e');
    }
  }

  /// Get group members with their details
  static Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        return [];
      }

      final groupData = groupDoc.data()!;
      final members = List<String>.from(groupData['members'] ?? []);
      final admins = List<String>.from(groupData['admins'] ?? []);
      final memberUsernames = Map<String, String>.from(groupData['memberUsernames'] ?? {});

      List<Map<String, dynamic>> memberDetails = [];

      for (String uid in members) {
        memberDetails.add({
          'uid': uid,
          'username': memberUsernames[uid] ?? await ChatFeatures.getUsername(uid),
          'isAdmin': admins.contains(uid),
        });
      }

      return memberDetails;
    } catch (e) {
      print('❌ Error getting group members: $e');
      return [];
    }
  }

  /// Leave group
  static Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await removeMember(
        groupId: groupId,
        memberUid: userId,
        currentUserUid: userId,
      );
    } catch (e) {
      throw e;
    }
  }
}