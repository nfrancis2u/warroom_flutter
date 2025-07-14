import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('groups').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create new group'),
                onTap: () => _createGroupDialog(context),
              ),
              const Divider(),
              ...docs.map((d) => _GroupTile(id: d.id, data: d.data())),
            ],
          );
        },
      ),
    );
  }

  void _createGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance.collection('groups').add({
                'name': nameCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'members': [uid],
                'created_at': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const _GroupTile({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final members = List<String>.from(data['members'] ?? []);
    final isMember = members.contains(user.uid);
    return ListTile(
      title: Text(data['name'] ?? ''),
      subtitle: Text(data['description'] ?? ''),
      trailing: ElevatedButton(
        onPressed: () async {
          await FirebaseFirestore.instance.collection('groups').doc(id).update({
            'members': isMember ? FieldValue.arrayRemove([user.uid]) : FieldValue.arrayUnion([user.uid]),
          });
        },
        child: Text(isMember ? 'Leave' : 'Join'),
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailPage(groupId: id))),
    );
  }
}

class GroupDetailPage extends StatelessWidget {
  final String groupId;
  const GroupDetailPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('groups').doc(groupId).snapshots(),
        builder: (context, groupSnap) {
          if (!groupSnap.hasData) return const Center(child: CircularProgressIndicator());
          final groupData = groupSnap.data!.data()!;
          return Column(
            children: [
              ListTile(title: Text(groupData['name']), subtitle: Text(groupData['description'] ?? '')),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('groupId', isEqualTo: groupId)
                      .orderBy('created_at', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('No posts in this group yet'));
                    return ListView(
                      children: docs
                          .map((d) => ListTile(
                                title: Text(d['content'] ?? ''),
                                subtitle: Text(d['authorName'] ?? ''),
                              ))
                          .toList(),
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