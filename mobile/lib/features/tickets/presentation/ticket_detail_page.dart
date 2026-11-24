import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/ticket.dart';
import 'cubit/ticket_detail_cubit.dart';

/// S13: a white ticket stub on the dark background, split by two half-circle notches:
/// movie, showtime and seats on top; a 200×200 QR and the booking code below. White
/// keeps the QR easy for scanners to read.
class TicketDetailPage extends StatelessWidget {
  const TicketDetailPage({super.key, required this.ticketId});

  /// The paid booking's id.
  final int ticketId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => TicketDetailCubit(sl(), ticketId)..load(),
    child: const TicketDetailView(),
  );
}

class TicketDetailView extends StatelessWidget {
  const TicketDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết vé')),
      body: BlocBuilder<TicketDetailCubit, TicketDetailState>(
        builder: (context, state) => switch ((state.ticket, state.failure)) {
          (null, final f?) => ErrorView(
            message: f.message,
            onRetry: context.read<TicketDetailCubit>().load,
          ),
          (null, _) => const Center(child: CircularProgressIndicator()),
          (final t?, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: TicketStub(ticket: t),
          ),
        },
      ),
    );
  }
}

class TicketStub extends StatelessWidget {
  const TicketStub({super.key, required this.ticket});

  final TicketDetail ticket;

  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF5B5B66);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final show = ticket.show;
    final label = text.bodySmall?.copyWith(color: _muted);
    final value = text.bodyLarge?.copyWith(
      color: _ink,
      fontWeight: FontWeight.w600,
    );
    Widget field(String name, String v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: label),
        Text(v, style: value),
      ],
    );

    return DefaultTextStyle.merge(
      style: const TextStyle(color: _ink),
      child: Column(
        children: [
          _Part(
            top: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  show.movieTitle,
                  style: text.titleLarge?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('${show.ageRating} · ${show.format}', style: label),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: field('Rạp', show.cinemaName)),
                    field('Phòng', show.auditoriumName),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: field('Ngày', formatDayChip(show.startAt))),
                    field('Giờ', formatTime(show.startAt)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                field('Ghế', ticket.seats.map((s) => s.label).join(', ')),
                if (ticket.combos.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  field(
                    'Combo',
                    ticket.combos
                        .map((c) => '${c.name} × ${c.quantity}')
                        .join(', '),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                field('Tổng tiền', formatVnd(ticket.totalAmount)),
              ],
            ),
          ),
          const _Notches(),
          _Part(
            top: false,
            child: Column(
              children: [
                QrImageView(
                  data: ticket.qrPayload,
                  size: 200,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Mã QR vé ${ticket.bookingCode}',
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ticket.bookingCode,
                  style: const TextStyle(
                    color: _ink,
                    fontFamily: 'monospace',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  ticket.upcoming
                      ? 'Đưa mã này cho nhân viên soát vé'
                      : 'Suất chiếu đã kết thúc',
                  style: label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({required this.top, required this.child});

  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(AppSpacing.cardRadius);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: top
            ? const BorderRadius.only(topLeft: r, topRight: r)
            : const BorderRadius.only(bottomLeft: r, bottomRight: r),
      ),
      child: child,
    );
  }
}

/// The tear line: two half-circle cut-outs in the page colour and a dashed line.
class _Notches extends StatelessWidget {
  const _Notches();

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    Widget notch(bool left) => Container(
      width: _size / 2,
      height: _size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: left
            ? const BorderRadius.horizontal(right: Radius.circular(_size))
            : const BorderRadius.horizontal(left: Radius.circular(_size)),
      ),
    );
    return Container(
      color: Colors.white,
      height: _size,
      child: Row(
        children: [
          notch(true),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  (c.maxWidth / 10).floor(),
                  (_) => Container(
                    width: 5,
                    height: 1,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          notch(false),
        ],
      ),
    );
  }
}
