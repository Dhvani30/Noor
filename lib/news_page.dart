import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ Added import
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final Dio _dio = Dio();
  final ScrollController _scrollController = ScrollController();

  int _page = 1;
  bool _isFetchingMore = false;
  List<Article> _allArticles = [];
  List<Article> _filteredArticles = [];
  bool _isLoading = true;
  bool _isPositiveOnly = true;

  static const List<String> _positiveSignalWords = [
    'wins',
    'won',
    'victory',
    'justice',
    'law passed',
    'policy',
    'reform',
    'empowered',
    'fights back',
    'speaks out',
    'breaks silence',
    'survivor',
    'awarded',
    'recognized',
    'celebrates',
    'success',
    'overcomes',
    'launches',
    'creates',
    'builds',
    'founds',
    'leads',
    'achieves',
    'honored',
    'landmark',
    'historic',
    'change',
    'hope',
    'resilience',
    'strength',
    'bravery',
    'activist',
    'advocates',
    'campaign',
    'movement',
    'safe space',
    'support',
    'healing',
    'recovery',
    'education',
    'awareness',
    'training',
    'workshop',
    'new program',
    'initiative',
    'scholarship',
    'mentorship',
    'leadership',
    'promoted',
    'elected',
    'appointed',
    'first woman',
    'role model',
  ];

  static const List<String> _extremeNegativeWords = [
    'killed',
    'murdered',
    'dead',
    'fatally',
    'corpse',
    'suicide',
    'dies',
  ];

  @override
  void initState() {
    super.initState();
    _fetchNews();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isFetchingMore || _isPositiveOnly) return;

    setState(() => _isFetchingMore = true);
    try {
      // 🔑 Get API key securely
      final String apiKey = dotenv.env['NEWS_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('News API key missing!')));
        return;
      }

      final response = await _dio.get(
        'https://newsapi.org/v2/everything?' // 🔥 Removed extra spaces
        'q="women\'s%20rights"%20OR%20"gender%20equality"%20OR%20"female%20empowerment"%20'
        'OR%20"women%20safety"%20OR%20"domestic%20violence"%20OR%20"sexual%20harassment"&'
        'language=en&'
        'sortBy=publishedAt&'
        'pageSize=20&'
        'page=${++_page}&'
        'apiKey=$apiKey',
      );

      final articlesJson = response.data['articles'] as List?;
      if (articlesJson == null || articlesJson.isEmpty) return;

      final newArticles = articlesJson
          .map((item) => Article.fromJson(item))
          .where((a) => a.title != null && !a.title!.contains('[Removed]'))
          .toList();

      setState(() {
        _allArticles.addAll(newArticles);
        _applyFilter();
      });
    } finally {
      setState(() => _isFetchingMore = false);
    }
  }

  Future<void> _fetchNews() async {
    try {
      // 🔑 Get API key securely
      final String apiKey = dotenv.env['NEWS_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('News API key missing!')));
        return;
      }

      final response = await _dio.get(
        'https://newsapi.org/v2/everything?' // 🔥 Removed extra spaces
        'q="women\'s%20safety"%20OR%20"women\'s%20rights"%20OR%20"female%20empowerment"%20'
        'OR%20"gender%20equality"%20OR%20"women%20leadership"%20OR%20"maternal%20health"%20'
        'OR%20"workplace%20discrimination"%20OR%20"sexual%20harassment"%20'
        'OR%20"domestic%20violence"%20OR%20"legal%20aid%20women"%20'
        'OR%20"education%20for%20girls"%20OR%20"women%20in%20STEM"&'
        'language=en&'
        'sortBy=publishedAt&'
        'pageSize=50&'
        'apiKey=$apiKey',
      );

      final articlesJson = response.data['articles'] as List?;
      if (articlesJson == null) throw Exception('No articles');

      final List<Article> articles = articlesJson
          .map((item) => Article.fromJson(item))
          .where((a) => a.title != null && !a.title!.contains('[Removed]'))
          .toList();

      setState(() {
        _allArticles = articles;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load news: $e')));
    }
  }

  void _applyFilter() {
    if (_isPositiveOnly) {
      _filteredArticles = _allArticles.where((article) {
        final text = '${article.title} ${article.description}'.toLowerCase();
        bool isExtremeNegative = _extremeNegativeWords.any(text.contains);
        if (isExtremeNegative) return false;
        bool hasPositiveSignal = _positiveSignalWords.any(text.contains);
        return hasPositiveSignal;
      }).toList();
    } else {
      _filteredArticles = List.from(_allArticles);
    }
  }

  void _onToggleChanged(bool? newValue) {
    if (newValue != null) {
      setState(() {
        _isPositiveOnly = newValue;
        _applyFilter();
        if (!_isPositiveOnly) {
          _page = 1;
          _fetchNews();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Women\'s News',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CupertinoSlidingSegmentedControl<bool>(
              groupValue: _isPositiveOnly,
              children: {
                true: Text(
                  'Stay Positive',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isPositiveOnly
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                false: Text(
                  'Neutral',
                  style: TextStyle(
                    fontSize: 12,
                    color: !_isPositiveOnly
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              },
              onValueChanged: _onToggleChanged,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _fetchNews(),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _filteredArticles.length + (_isFetchingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _filteredArticles.length) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    );
                  }
                  final article = _filteredArticles[index];
                  final formattedDate = _formatDate(article.publishedAt);

                  return GestureDetector(
                    onTap: () => _launchUrl(article.url),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF2D2D2D)
                              : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: article.urlToImage ?? '',
                              placeholder: (context, url) => Container(
                                height: 160,
                                color: theme.colorScheme.surface,
                                child: Icon(
                                  CupertinoIcons.news,
                                  size: 48,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 160,
                                color: theme.colorScheme.surface,
                                child: Icon(
                                  CupertinoIcons.exclamationmark_triangle,
                                  size: 48,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            article.title ?? 'Untitled',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          if (article.description != null)
                            Text(
                              article.description!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                article.source?.name ?? 'Unknown Source',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                              Text(
                                formattedDate,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy').format(date.toLocal());
    } catch (e) {
      return '';
    }
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }
}

// --- Models ---
class Article {
  final Source? source;
  final String? author;
  final String? title;
  final String? description;
  final String? url;
  final String? urlToImage;
  final String? publishedAt;
  final String? content;

  Article({
    this.source,
    this.author,
    this.title,
    this.description,
    this.url,
    this.urlToImage,
    this.publishedAt,
    this.content,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      source: json['source'] != null ? Source.fromJson(json['source']) : null,
      author: json['author'],
      title: json['title'],
      description: json['description'],
      url: json['url'],
      urlToImage: json['urlToImage'],
      publishedAt: json['publishedAt'],
      content: json['content'],
    );
  }
}

class Source {
  final String? id;
  final String? name;

  Source({this.id, this.name});

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(id: json['id'], name: json['name']);
  }
}
