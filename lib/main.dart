import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'screens/search_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/bible_lookup_page.dart';
import 'screens/groups_page.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Christian Social App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const AuthGate(),
        routes: {
          NewPostPage.routeName: (_) => const NewPostPage(),
        },
      ),
    );
  }
}

// Renders either Login/Register or the main Home feed based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    if (user == null) {
      return const LoginPage();
    }
    return const HomePage();
  }
}

// ------------------------------ AUTH SCREENS ------------------------------ //
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),      
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: pwdCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              onPressed: loading ? null : _signIn,
              child: loading
                  ? const CircularProgressIndicator.adaptive()
                  : const Text('Login'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterPage()),
              ),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: pwdCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),      
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: pwdCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              onPressed: loading ? null : _register,
              child: loading
                  ? const CircularProgressIndicator.adaptive()
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: pwdCtrl.text.trim(),
      );
      final user = cred.user!;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': '',
        'denomination': '',
        'favoriteScripture': '',
        'profileImageUrl': '',
        'followers': <String>[],
        'following': <String>[],
        'blockedUsers': <String>[],
        'blockedBy': <String>[],
        'created_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }
}

// ------------------------------ HOME FEED ------------------------------ //
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _setupPushToken();
  }

  Future<void> _setupPushToken() async {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (token != null && user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'fcmToken': token});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GroupsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(NewPostPage.routeName),
            icon: const Icon(Icons.add),
            tooltip: 'New post',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const PostList(),
    );
  }
}

class PostList extends StatelessWidget {
  const PostList({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Not signed in'));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
        final blocked = List<String>.from(userSnap.data!.data()?['blockedUsers'] ?? []);
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .orderBy('created_at', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs.where((d) => !blocked.contains(d['authorId'])).toList() ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('No posts to display'));
            }
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (_, i) {
                return PostTile(
                  postId: docs[i].id,
                  data: docs[i].data(),
                  currentUserId: currentUser.uid,
                );
              },
            );
          },
        );
      },
    );
  }
}

class PostTile extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final String? currentUserId;
  const PostTile({super.key, required this.postId, required this.data, this.currentUserId});

  @override
  State<PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<PostTile> {
  bool likeBusy = false;

  @override
  Widget build(BuildContext context) {
    final likes = List<String>.from(widget.data['likes'] ?? []);
    final isLiked = widget.currentUserId != null && likes.contains(widget.currentUserId);
    final createdAtTs = widget.data['created_at'] as Timestamp?;
    final createdAt = createdAtTs?.toDate();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailPage(postId: widget.postId)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.data['type'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Chip(label: Text(widget.data['type'])),
                ),
              if (widget.data['imageUrl'] != null && widget.data['imageUrl'] != '')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Image.network(widget.data['imageUrl'], fit: BoxFit.cover),
                ),
              Text(widget.data['content'] ?? '', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: GestureDetector(
                    child: Text('— ${widget.data['authorName'] ?? 'Anonymous'}', style: const TextStyle(decoration: TextDecoration.underline)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProfilePage(userId: widget.data['authorId'])),
                    ),
                  )),
                  if (createdAt != null)
                    Text('${createdAt.day}/${createdAt.month}/${createdAt.year}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  IconButton(
                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : null),
                    onPressed: likeBusy ? null : _toggleLike,
                  ),
                  Text(likes.length.toString()),
                  if (widget.data['type'] == 'Prayer Request') ...[
                    IconButton(
                      icon: const Icon(Icons.volunteer_activism),
                      onPressed: _togglePrayed,
                    ),
                    Text(List<String>.from(widget.data['prayedBy'] ?? []).length.toString()),
                  ],
                  IconButton(
                    icon: const Icon(Icons.comment_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PostDetailPage(postId: widget.postId)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.report_gmailerrorred),
                    onPressed: _reportPost,
                    tooltip: 'Report',
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (widget.currentUserId == null) return;
    setState(() => likeBusy = true);
    final docRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final isLiked = (widget.data['likes'] ?? []).contains(widget.currentUserId);
    await docRef.update({
      'likes': isLiked
          ? FieldValue.arrayRemove([widget.currentUserId])
          : FieldValue.arrayUnion([widget.currentUserId]),
    });
    // notify author if liked
    if (!isLiked && widget.data['authorId'] != null && widget.data['authorId'] != widget.currentUserId) {
      await FirebaseFirestore.instance.collection('users').doc(widget.data['authorId']).collection('notifications').add({
        'type': 'like',
        'fromUserId': widget.currentUserId,
        'postId': widget.postId,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    setState(() => likeBusy = false);
  }

  Future<void> _togglePrayed() async {
    if (widget.currentUserId == null) return;
    setState(() => likeBusy = true);
    final docRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final isPrayed = (widget.data['prayedBy'] ?? []).contains(widget.currentUserId);
    await docRef.update({
      'prayedBy': isPrayed
          ? FieldValue.arrayRemove([widget.currentUserId])
          : FieldValue.arrayUnion([widget.currentUserId]),
    });
    // notify author if prayed
    if (!isPrayed && widget.data['authorId'] != null && widget.data['authorId'] != widget.currentUserId) {
      await FirebaseFirestore.instance.collection('users').doc(widget.data['authorId']).collection('notifications').add({
        'type': 'prayed',
        'fromUserId': widget.currentUserId,
        'postId': widget.postId,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    setState(() => likeBusy = false);
  }

  Future<void> _reportPost() async {
    final userId = widget.currentUserId;
    if (userId == null) return;
    await FirebaseFirestore.instance.collection('reports').add({
      'postId': widget.postId,
      'reportedBy': userId,
      'created_at': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported. Thank you.')));
  }
}

// ------------------------------ NEW POST (with type & image) ------------------------------ //
class NewPostPage extends StatefulWidget {
  static const routeName = '/new-post';
  const NewPostPage({super.key});

  @override
  State<NewPostPage> createState() => _NewPostPageState();
}

class _NewPostPageState extends State<NewPostPage> {
  final ctrl = TextEditingController();
  bool loading = false;
  String _selectedType = 'Prayer Request';
  File? _pickedImage;
  final picker = ImagePicker();

  final postTypes = const ['Prayer Request', 'Testimony', 'Bible Verse'];

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share a post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: postTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
              decoration: const InputDecoration(labelText: 'Post type'),
            ),
            const SizedBox(height: 12),
            if (_pickedImage != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Image.file(_pickedImage!, height: 180),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _pickedImage = null),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo),
                label: const Text('Add image'),
              ),
            ),
            if (_selectedType == 'Bible Verse')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.book),
                  label: const Text('Lookup verse'),
                  onPressed: () async {
                    final verse = await Navigator.of(context).push<String>(
                      MaterialPageRoute(builder: (_) => const BibleLookupPage()),
                    );
                    if (verse != null && verse.isNotEmpty) {
                      ctrl.text = verse;
                    }
                  },
                ),
              ),
            TextField(
              controller: ctrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "What's on your heart today?",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : _submit,
              child: loading
                  ? const CircularProgressIndicator.adaptive()
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final content = ctrl.text.trim();
    if (content.isEmpty && _pickedImage == null) return;
    if (containsBannedWords(content)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Content contains inappropriate words.')));
      return;
    }
    setState(() => loading = true);

    final user = FirebaseAuth.instance.currentUser!;

    String authorName = user.email ?? 'Anonymous';
    final profileDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (profileDoc.exists) {
      authorName = profileDoc.data()?['displayName'] ?? authorName;
    }

    String? imageUrl;
    if (_pickedImage != null) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';
      final ref = FirebaseStorage.instance.ref().child('post_images/$fileName');
      await ref.putFile(_pickedImage!);
      imageUrl = await ref.getDownloadURL();
    }

    await FirebaseFirestore.instance.collection('posts').add({
      'content': content,
      'authorId': user.uid,
      'authorName': authorName,
      'created_at': FieldValue.serverTimestamp(),
      'type': _selectedType,
      'imageUrl': imageUrl ?? '',
      'likes': <String>[],
      'prayedBy': <String>[],
    });
    if (mounted) {
      setState(() => loading = false);
      Navigator.of(context).pop();
    }
  }
}

// ------------------------------ PROFILE ------------------------------ //
class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final displayCtrl = TextEditingController();
  final denomCtrl = TextEditingController();
  final verseCtrl = TextEditingController();
  bool loading = false;
  File? _photo;
  final picker = ImagePicker();

  @override
  void dispose() {
    displayCtrl.dispose();
    denomCtrl.dispose();
    verseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final uid = widget.userId ?? currentUser.uid;
    final isOwn = uid == currentUser.uid;
    return Scaffold(
      appBar: AppBar(title: Text(isOwn ? 'My Profile' : 'Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() ?? {};
          displayCtrl.text = data['displayName'] ?? '';
          denomCtrl.text = data['denomination'] ?? '';
          verseCtrl.text = data['favoriteScripture'] ?? '';
          final imageUrl = data['profileImageUrl'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _photo != null
                        ? FileImage(_photo!)
                        : (imageUrl != null && imageUrl.isNotEmpty)
                            ? NetworkImage(imageUrl) as ImageProvider
                            : null,
                    child: _photo == null && (imageUrl == null || imageUrl.isEmpty)
                        ? const Icon(Icons.camera_alt, size: 40)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: displayCtrl,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                TextField(
                  controller: denomCtrl,
                  decoration: const InputDecoration(labelText: 'Denomination'),
                ),
                TextField(
                  controller: verseCtrl,
                  decoration: const InputDecoration(labelText: 'Favorite scripture'),
                ),
                const SizedBox(height: 20),
                if (!isOwn)
                  FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox();
                      final following = List<String>.from(snap.data!.data()?['following'] ?? []);
                      final isFollowing = following.contains(uid);
                      return Column(
                        children: [
                          ElevatedButton(
                            onPressed: () => _toggleFollow(currentUser.uid, uid, isFollowing),
                            child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _blockUser(currentUser.uid, uid),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Block'),
                          ),
                        ],
                      );
                    },
                  ),
                if (isOwn) ...[
                  ElevatedButton(
                    onPressed: loading ? null : () => _save(uid),
                    child: loading
                        ? const CircularProgressIndicator.adaptive()
                        : const Text('Save changes'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleFollow(String me, String target, bool isFollowing) async {
    await FirebaseFirestore.instance.collection('users').doc(me).update({
      'following': isFollowing ? FieldValue.arrayRemove([target]) : FieldValue.arrayUnion([target]),
    });
    await FirebaseFirestore.instance.collection('users').doc(target).update({
      'followers': isFollowing ? FieldValue.arrayRemove([me]) : FieldValue.arrayUnion([me]),
    });
  }

  Future<void> _blockUser(String me, String target) async {
    await FirebaseFirestore.instance.collection('users').doc(me).update({
      'blockedUsers': FieldValue.arrayUnion([target]),
    });
    await FirebaseFirestore.instance.collection('users').doc(target).update({
      'blockedBy': FieldValue.arrayUnion([me]),
    });
  }

  Future<void> _save(String uid) async {
    setState(() => loading = true);
    String? downloadUrl;
    if (_photo != null) {
      final ref = FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');
      await ref.putFile(_photo!);
      downloadUrl = await ref.getDownloadURL();
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'displayName': displayCtrl.text.trim(),
      'denomination': denomCtrl.text.trim(),
      'favoriteScripture': verseCtrl.text.trim(),
      if (downloadUrl != null) 'profileImageUrl': downloadUrl,
    });
    if (mounted) setState(() => loading = false);
  }
}

// ------------------------------ POST DETAIL (comments) ------------------------------ //
class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final commentCtrl = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final user = FirebaseAuth.instance.currentUser!;
    final content = commentCtrl.text.trim();
    if (content.isEmpty) return;
    if (containsBannedWords(content)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment contains inappropriate words.')));
      return;
    }
    setState(() => sending = true);

    String authorName = user.email ?? 'Anonymous';
    final profileDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (profileDoc.exists) {
      authorName = profileDoc.data()?['displayName'] ?? authorName;
    }

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'content': content,
      'authorId': user.uid,
      'authorName': authorName,
      'created_at': FieldValue.serverTimestamp(),
    });
    // notify post author
    final postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
    final postAuthorId = postDoc.data()?['authorId'];
    if (postAuthorId != user.uid) {
      await FirebaseFirestore.instance.collection('users').doc(postAuthorId).collection('notifications').add({
        'type': 'comment',
        'fromUserId': user.uid,
        'postId': widget.postId,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    commentCtrl.clear();
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),      
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No comments yet'));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data();
                    final ts = data['created_at'] as Timestamp?;
                    final dt = ts?.toDate();
                    return ListTile(
                      title: Text(data['content'] ?? ''),
                      subtitle: Text('${data['authorName'] ?? ''} · ${dt != null ? '${dt.day}/${dt.month}/${dt.year}' : ''}'),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(hintText: 'Add a comment…'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sending ? null : _sendComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const bannedWords = ['badword1', 'badword2'];
bool containsBannedWords(String text) => bannedWords.any((w) => text.toLowerCase().contains(w));