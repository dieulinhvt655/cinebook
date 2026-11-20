import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/state_views.dart';

class ComboPage extends StatelessWidget {
  const ComboPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context) =>
      const ScreenPlaceholder(code: 'S09', title: 'Combo bắp nước');
}
