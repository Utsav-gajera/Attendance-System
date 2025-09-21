import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PerformanceUtils {
  static const int DEFAULT_PAGE_SIZE = 20;
  static const Duration CACHE_DURATION = Duration(minutes: 5);
  static const Duration DEBOUNCE_DURATION = Duration(milliseconds: 500);

  // Cache for storing frequently accessed data
  static final Map<String, CacheItem> _cache = {};

  // Stream subscriptions for proper disposal
  static final Map<String, StreamSubscription> _subscriptions = {};

  // Debouncer for search and input fields
  static Timer? _debounceTimer;

  // Cache management
  static void cacheData(String key, dynamic data, {Duration? duration}) {
    _cache[key] = CacheItem(
      data: data,
      timestamp: DateTime.now(),
      duration: duration ?? CACHE_DURATION,
    );
  }

  static T? getCachedData<T>(String key) {
    final item = _cache[key];
    if (item != null) {
      if (DateTime.now().difference(item.timestamp) < item.duration) {
        return item.data as T?;
      } else {
        _cache.remove(key);
      }
    }
    return null;
  }

  static void clearCache([String? key]) {
    if (key != null) {
      _cache.remove(key);
    } else {
      _cache.clear();
    }
  }

  static void clearExpiredCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, item) => 
        now.difference(item.timestamp) >= item.duration);
  }

  // Stream subscription management
  static void addSubscription(String key, StreamSubscription subscription) {
    _subscriptions[key]?.cancel();
    _subscriptions[key] = subscription;
  }

  static void cancelSubscription(String key) {
    _subscriptions[key]?.cancel();
    _subscriptions.remove(key);
  }

  static void cancelAllSubscriptions() {
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  // Debounced function execution
  static void debounce(VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(DEBOUNCE_DURATION, callback);
  }

  static void cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  // Optimized Firestore queries
  static Query optimizeQuery(Query query, {
    int? limit,
    bool useCache = true,
  }) {
    // Apply limit to reduce data transfer
    if (limit != null) {
      query = query.limit(limit);
    }

    // Enable persistence for offline support
    if (useCache) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    return query;
  }

  // Paginated data loading
  static Future<PaginatedResult<T>> loadPaginatedData<T>({
    required Query query,
    required T Function(DocumentSnapshot doc) mapper,
    DocumentSnapshot? startAfter,
    int pageSize = DEFAULT_PAGE_SIZE,
  }) async {
    try {
      Query paginatedQuery = query.limit(pageSize + 1); // +1 to check if there's more data
      
      if (startAfter != null) {
        paginatedQuery = paginatedQuery.startAfterDocument(startAfter);
      }

      final snapshot = await paginatedQuery.get();
      final docs = snapshot.docs;
      
      final hasMore = docs.length > pageSize;
      final items = docs.take(pageSize).map(mapper).toList();
      
      return PaginatedResult<T>(
        items: items,
        hasMore: hasMore,
        lastDocument: docs.isNotEmpty ? docs[docs.length - (hasMore ? 2 : 1)] : null,
      );
    } catch (e) {
      print('Error loading paginated data: $e');
      return PaginatedResult<T>(items: [], hasMore: false, lastDocument: null);
    }
  }

  // Lazy loading stream builder
  static StreamBuilder<QuerySnapshot> lazyStreamBuilder({
    required Query query,
    required Widget Function(BuildContext, AsyncSnapshot<QuerySnapshot>) builder,
    int? limit,
  }) {
    final optimizedQuery = optimizeQuery(query, limit: limit);
    
    return StreamBuilder<QuerySnapshot>(
      stream: optimizedQuery.snapshots(),
      builder: builder,
    );
  }

  // Memory usage monitoring (for debugging)
  static void logMemoryUsage() {
    if (kDebugMode) {
      print('Cache items: ${_cache.length}');
      print('Active subscriptions: ${_subscriptions.length}');
    }
  }

  // Image optimization
  static ImageProvider optimizeImage(String url, {
    double? width,
    double? height,
  }) {
    // For network images, we can add caching and resizing
    return NetworkImage(url);
  }

  // Dispose resources
  static void dispose() {
    cancelAllSubscriptions();
    cancelDebounce();
    clearCache();
  }
}

// Cache item class
class CacheItem {
  final dynamic data;
  final DateTime timestamp;
  final Duration duration;

  CacheItem({
    required this.data,
    required this.timestamp,
    required this.duration,
  });
}

// Paginated result class
class PaginatedResult<T> {
  final List<T> items;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;

  PaginatedResult({
    required this.items,
    required this.hasMore,
    this.lastDocument,
  });
}

// Optimized list widget with lazy loading
class OptimizedListView<T> extends StatefulWidget {
  final Query query;
  final T Function(DocumentSnapshot doc) itemMapper;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? emptyWidget;
  final Widget? errorWidget;
  final Widget? loadingWidget;
  final int pageSize;

  const OptimizedListView({
    Key? key,
    required this.query,
    required this.itemMapper,
    required this.itemBuilder,
    this.emptyWidget,
    this.errorWidget,
    this.loadingWidget,
    this.pageSize = PerformanceUtils.DEFAULT_PAGE_SIZE,
  }) : super(key: key);

  @override
  _OptimizedListViewState<T> createState() => _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends State<OptimizedListView<T>> {
  final List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final ScrollController _scrollController = ScrollController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await PerformanceUtils.loadPaginatedData<T>(
        query: widget.query,
        mapper: widget.itemMapper,
        startAfter: _lastDocument,
        pageSize: widget.pageSize,
      );

      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _lastDocument = result.lastDocument;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _hasMore = true;
      _lastDocument = null;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _items.isEmpty) {
      return widget.errorWidget ?? 
          Center(child: Text('Error: $_error', style: TextStyle(color: Colors.red)));
    }

    if (_items.isEmpty && _isLoading) {
      return widget.loadingWidget ?? 
          const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return widget.emptyWidget ?? 
          const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _items.length) {
            return widget.itemBuilder(context, _items[index]);
          } else {
            // Loading indicator at the bottom
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
    );
  }
}

// Optimized stream builder with automatic disposal
class OptimizedStreamBuilder<T> extends StatefulWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot) builder;
  final T? initialData;
  final String? subscriptionKey;

  const OptimizedStreamBuilder({
    Key? key,
    required this.stream,
    required this.builder,
    this.initialData,
    this.subscriptionKey,
  }) : super(key: key);

  @override
  _OptimizedStreamBuilderState<T> createState() => _OptimizedStreamBuilderState<T>();
}

class _OptimizedStreamBuilderState<T> extends State<OptimizedStreamBuilder<T>> {
  late StreamSubscription<T> _subscription;
  AsyncSnapshot<T> _snapshot = AsyncSnapshot<T>.nothing();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _snapshot = AsyncSnapshot<T>.withData(ConnectionState.none, widget.initialData!);
    }
    _subscribe();
  }

  @override
  void didUpdateWidget(OptimizedStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _snapshot = _snapshot.inState(ConnectionState.waiting);
    _subscription = widget.stream.listen(
      (T data) {
        setState(() {
          _snapshot = AsyncSnapshot<T>.withData(ConnectionState.active, data);
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        setState(() {
          _snapshot = AsyncSnapshot<T>.withError(ConnectionState.active, error, stackTrace);
        });
      },
      onDone: () {
        setState(() {
          _snapshot = _snapshot.inState(ConnectionState.done);
        });
      },
    );

    // Register subscription for management
    if (widget.subscriptionKey != null) {
      PerformanceUtils.addSubscription(widget.subscriptionKey!, _subscription);
    }
  }

  void _unsubscribe() {
    _subscription.cancel();
    if (widget.subscriptionKey != null) {
      PerformanceUtils.cancelSubscription(widget.subscriptionKey!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _snapshot);
  }
}

// Memory-efficient image widget
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? 
            Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / 
                      loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? 
            Container(
              width: width,
              height: height,
              color: Colors.grey[300],
              child: Icon(Icons.error, color: Colors.grey[600]),
            );
      },
    );
  }
}