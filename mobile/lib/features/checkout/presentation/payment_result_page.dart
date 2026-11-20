import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/state_views.dart';

class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context) =>
      const ScreenPlaceholder(code: 'S11', title: 'Kết quả thanh toán');
}
