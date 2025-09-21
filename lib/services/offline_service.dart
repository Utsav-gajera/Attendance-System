import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  static const String OFFLINE_DATA_PREFIX = 'offline_data_';
  static const String PENDING_OPERATIONS_KEY = 'pending_operations';
  static const String LAST_SYNC_KEY = 'last_sync';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  
  bool _isOnline = true;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();

  // Offline data storage
  SharedPreferences? _prefs;
  final List<OfflineOperation> _pendingOperations = [];

  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Enable Firestore offline persistence
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      print('Firestore persistence already enabled or error: $e');
    }

    // Load pending operations from storage
    await _loadPendingOperations();

    // Monitor connectivity
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _onConnectivityChanged(result);
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;
    
    _connectionStatusController.add(_isOnline);

    if (!wasOnline && _isOnline) {
      // Back online - sync pending operations
      _syncPendingOperations();
    }
  }

  // Save data for offline access
  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    if (_prefs == null) return;
    
    final cacheKey = '$OFFLINE_DATA_PREFIX$key';
    final jsonString = json.encode({
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    await _prefs!.setString(cacheKey, jsonString);
  }

  // Retrieve cached data
  Map<String, dynamic>? getCachedData(String key) {
    if (_prefs == null) return null;
    
    final cacheKey = '$OFFLINE_DATA_PREFIX$key';
    final jsonString = _prefs!.getString(cacheKey);
    
    if (jsonString != null) {
      final cached = json.decode(jsonString);
      return cached['data'] as Map<String, dynamic>;
    }
    
    return null;
  }

  // Store operation for later sync when online
  Future<void> storeOfflineOperation(OfflineOperation operation) async {
    _pendingOperations.add(operation);
    await _savePendingOperations();
  }

  // Execute operation (online or queue for offline)
  Future<bool> executeOperation(OfflineOperation operation) async {
    if (_isOnline) {
      try {
        await _executeOperationOnline(operation);
        return true;
      } catch (e) {
        print('Error executing operation online: $e');
        await storeOfflineOperation(operation);
        return false;
      }
    } else {
      await storeOfflineOperation(operation);
      return false;
    }
  }

  // Execute operation when online
  Future<void> _executeOperationOnline(OfflineOperation operation) async {
    final docRef = _firestore.collection(operation.collection).doc(operation.documentId);
    
    switch (operation.type) {
      case OperationType.create:
        await docRef.set(operation.data);
        break;
      case OperationType.update:
        await docRef.update(operation.data);
        break;
      case OperationType.delete:
        await docRef.delete();
        break;
    }
  }

  // Sync all pending operations when back online
  Future<void> _syncPendingOperations() async {
    if (_pendingOperations.isEmpty) return;

    final operationsToSync = List<OfflineOperation>.from(_pendingOperations);
    _pendingOperations.clear();
    await _savePendingOperations();

    for (final operation in operationsToSync) {
      try {
        await _executeOperationOnline(operation);
        print('Synced operation: ${operation.type} on ${operation.collection}');
      } catch (e) {
        print('Error syncing operation: $e');
        // Re-add failed operations back to queue
        _pendingOperations.add(operation);
      }
    }

    if (_pendingOperations.isNotEmpty) {
      await _savePendingOperations();
    }

    // Update last sync timestamp
    await _prefs!.setString(LAST_SYNC_KEY, DateTime.now().toIso8601String());
  }

  // Load pending operations from storage
  Future<void> _loadPendingOperations() async {
    if (_prefs == null) return;
    
    final jsonString = _prefs!.getString(PENDING_OPERATIONS_KEY);
    if (jsonString != null) {
      final List<dynamic> operationsList = json.decode(jsonString);
      _pendingOperations.clear();
      _pendingOperations.addAll(
        operationsList.map((op) => OfflineOperation.fromJson(op))
      );
    }
  }

  // Save pending operations to storage
  Future<void> _savePendingOperations() async {
    if (_prefs == null) return;
    
    final jsonString = json.encode(
      _pendingOperations.map((op) => op.toJson()).toList()
    );
    await _prefs!.setString(PENDING_OPERATIONS_KEY, jsonString);
  }

  // Get last sync time
  DateTime? getLastSyncTime() {
    if (_prefs == null) return null;
    
    final syncTimeString = _prefs!.getString(LAST_SYNC_KEY);
    if (syncTimeString != null) {
      return DateTime.parse(syncTimeString);
    }
    return null;
  }

  // Clear all cached data
  Future<void> clearCache() async {
    if (_prefs == null) return;
    
    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith(OFFLINE_DATA_PREFIX)) {
        await _prefs!.remove(key);
      }
    }
  }

  // Get pending operations count
  int get pendingOperationsCount => _pendingOperations.length;

  // Force sync
  Future<void> forceSync() async {
    if (_isOnline) {
      await _syncPendingOperations();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionStatusController.close();
  }
}

// Operation types for offline sync
enum OperationType { create, update, delete }

// Offline operation model
class OfflineOperation {
  final String id;
  final OperationType type;
  final String collection;
  final String? documentId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  OfflineOperation({
    required this.id,
    required this.type,
    required this.collection,
    this.documentId,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'collection': collection,
      'documentId': documentId,
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'],
      type: OperationType.values.firstWhere((e) => e.name == json['type']),
      collection: json['collection'],
      documentId: json['documentId'],
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
}

// Offline-aware Firestore wrapper
class OfflineFirestore {
  static final OfflineService _offlineService = OfflineService();

  // Create document with offline support
  static Future<bool> createDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final operation = OfflineOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: OperationType.create,
      collection: collection,
      documentId: documentId,
      data: data,
      timestamp: DateTime.now(),
    );

    // Cache data for offline access
    await _offlineService.cacheData('${collection}_$documentId', data);

    return await _offlineService.executeOperation(operation);
  }

  // Update document with offline support
  static Future<bool> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final operation = OfflineOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: OperationType.update,
      collection: collection,
      documentId: documentId,
      data: data,
      timestamp: DateTime.now(),
    );

    // Update cached data
    final existingData = _offlineService.getCachedData('${collection}_$documentId') ?? {};
    existingData.addAll(data);
    await _offlineService.cacheData('${collection}_$documentId', existingData);

    return await _offlineService.executeOperation(operation);
  }

  // Delete document with offline support
  static Future<bool> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    final operation = OfflineOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: OperationType.delete,
      collection: collection,
      documentId: documentId,
      data: {},
      timestamp: DateTime.now(),
    );

    return await _offlineService.executeOperation(operation);
  }

  // Get document with offline fallback
  static Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    if (_offlineService.isOnline) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(documentId)
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          // Cache for offline access
          await _offlineService.cacheData('${collection}_$documentId', data);
          return data;
        }
      } catch (e) {
        print('Error fetching document online: $e');
      }
    }

    // Fallback to cached data
    return _offlineService.getCachedData('${collection}_$documentId');
  }
}

// Connection status widget
class ConnectionStatusWidget extends StatefulWidget {
  final Widget child;

  const ConnectionStatusWidget({Key? key, required this.child}) : super(key: key);

  @override
  _ConnectionStatusWidgetState createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  final OfflineService _offlineService = OfflineService();
  bool _isOnline = true;
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _isOnline = _offlineService.isOnline;
    _subscription = _offlineService.connectionStatusStream.listen((isOnline) {
      setState(() {
        _isOnline = isOnline;
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isOnline)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(8),
            color: Colors.orange,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Offline mode - Changes will sync when connected',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

// Sync status widget
class SyncStatusWidget extends StatefulWidget {
  const SyncStatusWidget({Key? key}) : super(key: key);

  @override
  _SyncStatusWidgetState createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final OfflineService _offlineService = OfflineService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _offlineService.connectionStatusStream,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        final pendingCount = _offlineService.pendingOperationsCount;
        final lastSync = _offlineService.getLastSyncTime();

        return Container(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isOnline ? Icons.cloud_done : Icons.cloud_off,
                    color: isOnline ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isOnline ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
              if (pendingCount > 0) ...[
                SizedBox(height: 8),
                Text(
                  '$pendingCount pending changes',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (lastSync != null) ...[
                SizedBox(height: 4),
                Text(
                  'Last sync: ${_formatTime(lastSync)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (isOnline && pendingCount > 0)
                TextButton(
                  onPressed: () => _offlineService.forceSync(),
                  child: Text('Sync Now'),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}