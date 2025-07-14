import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BibleLookupPage extends StatefulWidget {
  const BibleLookupPage({super.key});

  @override
  State<BibleLookupPage> createState() => _BibleLookupPageState();
}

class _BibleLookupPageState extends State<BibleLookupPage> {
  final TextEditingController _refCtrl = TextEditingController();
  String? _verseText;
  bool _loading = false;
  String? _error;

  Future<void> _fetchVerse() async {
    final ref = _refCtrl.text.trim();
    if (ref.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = Uri.parse('https://bible-api.com/${Uri.encodeComponent(ref)}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _verseText = data['text']);
      } else {
        setState(() => _error = 'Verse not found');
      }
    } catch (e) {
      setState(() => _error = 'Error fetching verse');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bible Lookup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'Reference (e.g., John 3:16)',
              ),
              onSubmitted: (_) => _fetchVerse(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loading ? null : _fetchVerse, child: const Text('Search')),
            const SizedBox(height: 20),
            if (_loading) const CircularProgressIndicator(),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_verseText != null) Expanded(child: SingleChildScrollView(child: Text(_verseText!))),
            if (_verseText != null)
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_verseText),
                child: const Text('Use this verse'),
              ),
          ],
        ),
      ),
    );
  }
}