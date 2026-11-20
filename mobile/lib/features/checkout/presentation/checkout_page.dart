import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/state_views.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context) =>
      const ScreenPlaceholder(code: 'S10', title: 'Xác nhận & thanh toán');
}
