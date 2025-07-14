import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(hintText: 'Search…', border: InputBorder.none),
          onChanged: (_) => setState(() {}),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Posts'), Tab(text: 'People')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PostsTab(query: _searchCtrl.text),
          _UsersTab(query: _searchCtrl.text),
        ],
      ),
    );
  }
}

class _PostsTab extends StatelessWidget {
  final String query;
  const _PostsTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final lower = query.toLowerCase();
    if (lower.length < 2) {
      return const Center(child: Text('Type at least 2 characters'));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('posts').limit(50).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final matched = snapshot.data!.docs.where((d) => (d['content'] as String).toLowerCase().contains(lower)).toList();
        if (matched.isEmpty) return const Center(child: Text('No matching posts'));
        return ListView(
          children: matched
              .map((doc) => ListTile(
                    title: Text(doc['content'] ?? ''),
                    subtitle: Text(doc['authorName'] ?? ''),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _UsersTab extends StatelessWidget {
  final String query;
  const _UsersTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final lower = query.toLowerCase();
    if (lower.length < 2) {
      return const Center(child: Text('Type at least 2 characters'));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(50).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final matched = snapshot.data!.docs.where((d) {
          final name = (d['displayName'] ?? d['email'] ?? '') as String;
          return name.toLowerCase().contains(lower);
        }).toList();
        if (matched.isEmpty) return const Center(child: Text('No matching people'));
        return ListView(
          children: matched
              .map((doc) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(doc['displayName'] ?? doc['email'] ?? ''),
                  ))
              .toList(),
        );
      },
    );
  }
}