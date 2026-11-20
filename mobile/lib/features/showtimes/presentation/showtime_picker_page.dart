import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/state_views.dart';

class ShowtimePickerPage extends StatelessWidget {
  const ShowtimePickerPage({super.key, required this.movieId});

  final int movieId;

  @override
  Widget build(BuildContext context) =>
      const ScreenPlaceholder(code: 'S07', title: 'Chọn suất chiếu');
}
