import 'package:go_router/go_router.dart';

import '../features/categories/presentation/category_page.dart';
import '../features/budget/presentation/home_page.dart';

// Keep Flutter's default hash URLs so GitHub Pages can reload nested routes.
final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/category/:id',
      builder: (context, state) =>
          CategoryPage(categoryId: int.parse(state.pathParameters['id']!)),
    ),
  ],
);
