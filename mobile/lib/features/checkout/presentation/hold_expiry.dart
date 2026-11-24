import 'package:material_ui/material_ui.dart';

/// How a hold screen (S09/S10) was left, returned to the screen below it.
enum HoldExit { expired }

/// "Hết thời gian giữ ghế": cannot be dismissed; the only way on is back to S08.
Future<void> showHoldExpiredDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: const Text('Hết thời gian giữ ghế'),
      content: const Text(
        'Ghế đã được nhả cho người khác. Vui lòng chọn lại ghế.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Chọn lại ghế'),
        ),
      ],
    ),
  ),
);

/// Closes everything above this screen's route, then the screen itself with [result].
void popThisScreen(BuildContext context, [Object? result]) {
  final self = ModalRoute.of(context);
  Navigator.of(context)
    ..popUntil((r) => r == self)
    ..pop(result);
}
