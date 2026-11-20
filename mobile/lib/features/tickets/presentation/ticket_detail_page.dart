import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/state_views.dart';

class TicketDetailPage extends StatelessWidget {
  const TicketDetailPage({super.key, required this.ticketId});

  final int ticketId;

  @override
  Widget build(BuildContext context) =>
      const ScreenPlaceholder(code: 'S13', title: 'Chi tiết vé');
}
