import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/firebase_repo.dart';
import '../services/local_store.dart';
import '../services/download_service.dart';
import '../theme.dart';
import 'pdf_viewer_screen.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  List<Book> _books = [];
  bool _loading = true;
  final Set<String> _downloading = {};
  final Map<String, double> _progress = {};

  @override
  void initState() {
    super.initState();
    _loadCache();
    _refresh();
  }

  void _loadCache() {
    final cached = LocalStore.getBooks()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _books = cached;
      _loading = cached.isEmpty;
    });
  }

  Future<void> _refresh() async {
    final books = await FirebaseRepo.fetchBooks();
    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  Future<void> _download(Book book) async {
    if (_downloading.contains(book.id)) return;
    if (book.pdfUrl.isEmpty) {
      _snack('لا يتوفر رابط لهذا الكتاب.');
      return;
    }
    setState(() {
      _downloading.add(book.id);
      _progress[book.id] = 0;
    });
    try {
      await DownloadService.downloadBook(
        book.id,
        book.pdfUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress[book.id] = p);
        },
      );
      _snack('تم تحميل الكتاب بنجاح.');
    } catch (_) {
      _snack('تعذر تحميل الكتاب.');
    }
    if (mounted) {
      setState(() {
        _downloading.remove(book.id);
        _progress.remove(book.id);
      });
    }
  }

  Future<void> _open(Book book) async {
    final local = DownloadService.localBookPath(book.id);
    if (local != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(path: local, title: book.name),
        ),
      );
      return;
    }
    // Not downloaded: open online through a viewer.
    if (book.pdfUrl.isEmpty) {
      _snack('لا يتوفر رابط لهذا الكتاب.');
      return;
    }
    final viewer = book.pdfUrl.contains('firebasestorage.googleapis.com')
        ? 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(book.pdfUrl)}'
        : book.pdfUrl;
    final uri = Uri.parse(viewer);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('تعذر فتح الكتاب.');
    }
  }

  Future<void> _share(Book book) async {
    final local = DownloadService.localBookPath(book.id);
    if (local != null) {
      await Share.shareXFiles([XFile(local)], subject: book.name);
    } else {
      _snack('حمّل الكتاب أولاً لمشاركته.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الكتب')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _books.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'يجب الاتصال بالإنترنت أول مرة لتحميل الكتب.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _books.length,
                    itemBuilder: (context, i) => _buildCard(_books[i]),
                  ),
      ),
    );
  }

  Widget _buildCard(Book book) {
    final isDownloaded = DownloadService.isBookDownloaded(book.id);
    final isDownloading = _downloading.contains(book.id);
    final progress = _progress[book.id] ?? 0;

    return Card(
      color: kTeal,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kGold, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.menu_book, color: kGold, size: 36),
            const SizedBox(height: 8),
            Text(
              book.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold),
            ),
            if (book.author.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('المؤلف: ${book.author}',
                    style: const TextStyle(color: kGold, fontSize: 15)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kBlue),
                  onPressed: () => _open(book),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(isDownloaded ? 'فتح' : 'فتح أونلاين'),
                ),
                if (!isDownloaded)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kOrange),
                    onPressed: isDownloading ? null : () => _download(book),
                    icon: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download, size: 18),
                    label: Text(isDownloading
                        ? '${progress.toStringAsFixed(0)}%'
                        : 'تحميل'),
                  ),
                if (isDownloaded)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kSlate),
                    onPressed: () => _share(book),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('مشاركة'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
