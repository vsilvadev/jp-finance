import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/app_controller.dart';
import 'core/database/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(AppDatabase());
  await controller.load();
  runApp(JapanTripApp(controller: controller));
}
