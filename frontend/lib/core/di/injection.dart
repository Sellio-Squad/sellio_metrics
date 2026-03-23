import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'package:sellio_metrics/core/di/injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
void configureDependencies(String environment) => getIt.init(environment: environment);
