import 'package:flutter/widgets.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';
import 'home_screen_base.dart' as base;

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.space,
    required this.repository,
  });

  final FinancialSpace space;
  final FolegoRepository repository;

  @override
  Widget build(BuildContext context) {
    return RealtimeRefreshView(
      domain: AppRealtimeDomain.home,
      identity: space.id,
      builder: (key) => base.HomeScreen(
        key: key,
        space: space,
        repository: repository,
      ),
    );
  }
}
