import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../cubit/city_cubit.dart';

/// App-bar button with the chosen city; opens a sheet to pick another one.
class CityButton extends StatelessWidget {
  const CityButton({super.key});

  static const everywhere = 'Toàn quốc';

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<CityCubit>();
    if (cubit.state.cities.isEmpty) unawaited(cubit.load());
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<CityCubit, CityState>(
          builder: (sheet, state) {
            void choose(String? city) {
              unawaited(cubit.select(city));
              Navigator.pop(sheet);
            }

            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (name, count) in [
                    (null, null),
                    for (final c in state.cities) (c.name, c.cinemaCount),
                  ])
                    ListTile(
                      leading: Icon(
                        name == state.selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: name == state.selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      title: Text(name ?? everywhere),
                      subtitle: count == null ? null : Text('$count rạp'),
                      onTap: () => choose(name),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final city = context.select((CityCubit c) => c.state.selected);
    return TextButton.icon(
      onPressed: () => _pick(context),
      icon: const Icon(Icons.place_outlined, size: 18),
      label: Text(city ?? everywhere, overflow: TextOverflow.ellipsis),
    );
  }
}
