import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/state_views.dart';

class MovieDetailPage extends StatelessWidget {
  const MovieDetailPage({super.key, required this.movieId});

  final int movieId;

  @override
  Widget build(BuildContext context) =>
      const ScreenPlaceholder(code: 'S06', title: 'Chi tiết phim');
}
