import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
