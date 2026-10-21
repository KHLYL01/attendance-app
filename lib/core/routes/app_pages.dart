import 'package:get/get.dart';

import '../../features/home/home_binding.dart';
import '../../features/home/home_shell.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final List<GetPage<dynamic>> pages = [
    GetPage(name: AppRoutes.home, page: () => const HomeShell(), binding: HomeBinding()),
  ];
}
