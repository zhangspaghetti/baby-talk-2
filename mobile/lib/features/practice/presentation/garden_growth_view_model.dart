import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';

enum GardenGrowthLoadStatus { idle, loading, ready, empty, error }

class GardenGrowthViewModel extends ChangeNotifier {
  GardenGrowthViewModel({
    required GardenGrowthRepository repository,
    this.refreshTimeout = const Duration(seconds: 4),
  }) : _repository = repository;

  final GardenGrowthRepository _repository;
  final Duration refreshTimeout;

  GardenGrowthSnapshot _snapshot = GardenGrowthSnapshot.empty();
  GardenGrowthLoadStatus _status = GardenGrowthLoadStatus.idle;
  bool _isRefreshing = false;
  String? _message;

  GardenGrowthSnapshot get snapshot => _snapshot;
  GardenGrowthLoadStatus get status => _status;
  bool get isRefreshing => _isRefreshing;
  String? get message => _message;

  bool get isReady => _status == GardenGrowthLoadStatus.ready;
  bool get isEmpty => _status == GardenGrowthLoadStatus.empty;
  bool get hasError => _status == GardenGrowthLoadStatus.error;

  Future<void> initialize() {
    if (_status != GardenGrowthLoadStatus.idle || _isRefreshing) {
      return Future.value();
    }
    return refresh();
  }

  Future<void> refresh() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    if (_status == GardenGrowthLoadStatus.idle) {
      _status = GardenGrowthLoadStatus.loading;
      notifyListeners();
    }

    try {
      final nextSnapshot = await _repository
          .buildSnapshot()
          .timeout(refreshTimeout);
      _snapshot = nextSnapshot;
      _status = nextSnapshot.isEmpty
          ? GardenGrowthLoadStatus.empty
          : GardenGrowthLoadStatus.ready;
      _message = nextSnapshot.projectionWarning;
    } on TimeoutException {
      _status = GardenGrowthLoadStatus.error;
      _message = '成长投影刷新超时，先保留上一次稳定结果。';
    } catch (error) {
      _status = GardenGrowthLoadStatus.error;
      _message = '成长投影暂时不可用：$error';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
