import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/state_views.dart';

class SeatMapPage extends StatelessWidget {
  const SeatMapPage({super.key, required this.showtimeId});

  final int showtimeId;

  @override
  Widget build(BuildContext context) =>
      const ScreenPlaceholder(code: 'S08', title: 'Sơ đồ ghế');
}
