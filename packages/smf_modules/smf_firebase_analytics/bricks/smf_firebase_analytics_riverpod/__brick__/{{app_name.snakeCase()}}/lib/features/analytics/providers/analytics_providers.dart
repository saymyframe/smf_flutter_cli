import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:{{app_name.snakeCase()}}/core/services/analytics/i_analytics_service.dart';
import 'package:{{app_name.snakeCase()}}/core/typedef.dart';

final analyticsServiceProvider = Provider<IAnalyticsService>((ref) => getIt());
