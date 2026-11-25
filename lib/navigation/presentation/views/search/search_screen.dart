import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:rumbo_mobile_application/injections.dart';
import 'package:rumbo_mobile_application/navigation/application/destination_search_facade_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/presentation/utils/mockup_palette.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/bloc/destination_search_bloc.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/bloc/destination_search_event.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/bloc/destination_search_state.dart';
import 'package:rumbo_mobile_application/navigation/presentation/widgets/destination_tiles.dart';
import 'package:rumbo_mobile_application/navigation/presentation/widgets/navigation_chrome.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DestinationSearchBloc(
        facade: serviceLocator<DestinationSearchFacadeService>(),
      )..add(const DirectoryRequested()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(Destination destination) =>
      context.read<DestinationSearchBloc>().add(DestinationSelected(destination));

  @override
  Widget build(BuildContext context) {
    return BlocListener<DestinationSearchBloc, DestinationSearchState>(
      listenWhen: (previous, current) =>
          current.selection != null || current.selectionError != null,
      listener: (context, state) {
        final bloc = context.read<DestinationSearchBloc>();
        final destination = state.selection;
        final error = state.selectionError;
        if (destination != null) {
          context.push('/search/destination/${destination.id}', extra: destination);
        } else if (error != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error)));
        }
        bloc.add(const SelectionHandled());
      },
      child: Scaffold(
        backgroundColor: MockupPalette.background,
        body: SafeArea(
          child: BlocBuilder<DestinationSearchBloc, DestinationSearchState>(
            builder: (context, state) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const NavigationTopBar(),
                const SizedBox(height: 22),
                ..._body(context, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, DestinationSearchState state) {
    switch (state.status) {
      case DirectoryStatus.loading:
        return const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: MockupPalette.primary)),
        ];
      case DirectoryStatus.failure:
        return [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off, size: 48, color: MockupPalette.textMuted),
          const SizedBox(height: 12),
          const Text(
            'No pudimos cargar los destinos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MockupPalette.primary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () =>
                  context.read<DestinationSearchBloc>().add(const DirectoryRequested()),
              style: FilledButton.styleFrom(backgroundColor: MockupPalette.primary),
              child: const Text('Reintentar'),
            ),
          ),
        ];
      case DirectoryStatus.ready:
        return [
          _SearchField(controller: _controller),
          const SizedBox(height: 12),
          if (!state.isSearching) ..._idle(state)
          else if (state.hasNoResults) ..._noResults(state)
          else ..._results(state),
          const SizedBox(height: 20),
          HelpCard(
            onGuide: () => context.read<DestinationSearchBloc>().add(const HelpRequested()),
          ),
        ];
    }
  }

  List<Widget> _idle(DestinationSearchState state) => [
        const _Heading(),
        const SizedBox(height: 16),
        const _LocationCard(),
        const SizedBox(height: 16),
        const Text(
          'Consejo: busca por número de consultorio o especialidad',
          style: TextStyle(color: MockupPalette.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'CATEGORÍAS', trailing: '6 opciones'),
        const SizedBox(height: 12),
        _CategoryWrap(selected: state.kind),
        if (state.recents.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionHeader(
            title: 'DESTINOS RECIENTES',
            trailing: 'Limpiar',
            onTrailingTap: () =>
                context.read<DestinationSearchBloc>().add(const RecentsCleared()),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: MockupPalette.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var i = 0; i < state.recents.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: MockupPalette.divider),
                  RecentDestinationTile(
                    destination: state.recents[i],
                    onTap: () => _select(state.recents[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ];

  List<Widget> _results(DestinationSearchState state) {
    final bloc = context.read<DestinationSearchBloc>();
    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Presiona Enter para actualizar',
              style: TextStyle(color: MockupPalette.textMuted, fontSize: 12),
            ),
          ),
          Text(
            'Filtro: ${state.kind?.categoryLabel ?? 'Todos'}',
            style: const TextStyle(color: MockupPalette.textMuted, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          CategoryPill(
            label: 'Todas (${state.totalCount})',
            selected: state.kind == null,
            onTap: () {
              if (state.kind != null) bloc.add(CategoryToggled(state.kind!));
            },
          ),
          for (final entry in state.kindCounts.entries)
            CategoryPill(
              label: '${entry.key.categoryLabel} (${entry.value})',
              selected: state.kind == entry.key,
              onTap: () => bloc.add(CategoryToggled(entry.key)),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: Text(
              state.query.trim().isEmpty
                  ? (state.kind?.categoryLabel ?? 'Resultados')
                  : 'Resultados para "${state.query.trim()}"',
              style: const TextStyle(
                color: MockupPalette.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            '${state.matches.length} ${state.matches.length == 1 ? 'coincidencia' : 'coincidencias'}',
            style: const TextStyle(color: MockupPalette.textMuted, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 12),
      for (final destination in state.matches) ...[
        DestinationResultCard(destination: destination, onTap: () => _select(destination)),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _noResults(DestinationSearchState state) {
    final suggestion = state.suggestion;
    return [
      const SizedBox(height: 18),
      const Icon(Icons.search_off, size: 44, color: MockupPalette.textMuted),
      const SizedBox(height: 12),
      Text(
        state.query.trim().isEmpty
            ? 'No hay destinos en esta categoría.'
            : "No hay resultados para '${state.query.trim()}'.",
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: MockupPalette.primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      if (suggestion != null) ...[
        const SizedBox(height: 6),
        Text(
          '¿Quisiste decir ${suggestion.name.split(' —').first}?',
          textAlign: TextAlign.center,
          style: const TextStyle(color: MockupPalette.primary, fontSize: 14),
        ),
      ],
      const SizedBox(height: 6),
      const Text(
        'Revisa la escritura o explora las áreas frecuentes de la clínica.',
        textAlign: TextAlign.center,
        style: TextStyle(color: MockupPalette.textMuted, fontSize: 13),
      ),
      if (suggestion != null) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MockupPalette.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, color: MockupPalette.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destino recomendado',
                      style: TextStyle(color: MockupPalette.textMuted, fontSize: 12),
                    ),
                    Text(
                      '${suggestion.name} (${suggestion.locationLabel})',
                      style: const TextStyle(
                        color: MockupPalette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: () => _select(suggestion), child: const Text('Ver')),
            ],
          ),
        ),
      ],
      const SizedBox(height: 22),
      const Text(
        'Prueba con una de estas categorías:',
        style: TextStyle(color: MockupPalette.primary, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      _CategoryWrap(selected: state.kind, clearQueryOnTap: true, controller: _controller),
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿A dónde vas?',
          style: TextStyle(
            color: MockupPalette.primary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Encuentra consultorios, médicos y servicios',
          style: TextStyle(color: MockupPalette.textMuted, fontSize: 14),
        ),
      ],
    );
  }
}

/// Ubicación actual. Es un valor fijo hasta integrar el posicionamiento BLE.
class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: MockupPalette.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.near_me_outlined, color: MockupPalette.primary, size: 20),
          SizedBox(width: 10),
          Text(
            'Estás en: Entrada principal · Piso 1',
            style: TextStyle(color: MockupPalette.primary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DestinationSearchBloc>();
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: (value) => bloc.add(QueryChanged(value)),
      onSubmitted: (value) => bloc.add(QueryChanged(value)),
      style: const TextStyle(color: MockupPalette.primary),
      decoration: InputDecoration(
        hintText: 'Busca médico, especialidad o servicio',
        hintStyle: const TextStyle(color: MockupPalette.textMuted, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: MockupPalette.textMuted),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const Icon(Icons.mic_none, color: MockupPalette.textMuted)
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(Icons.close, color: MockupPalette.textMuted),
                  onPressed: () {
                    controller.clear();
                    bloc.add(const QueryChanged(''));
                  },
                ),
        ),
        filled: true,
        fillColor: MockupPalette.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing, this.onTrailingTap});

  final String title;
  final String trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: MockupPalette.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.6,
          ),
        ),
        GestureDetector(
          onTap: onTrailingTap,
          child: Text(
            trailing,
            style: const TextStyle(color: MockupPalette.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _CategoryWrap extends StatelessWidget {
  const _CategoryWrap({required this.selected, this.clearQueryOnTap = false, this.controller});

  final DestinationKind? selected;
  final bool clearQueryOnTap;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DestinationSearchBloc>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in DestinationKind.values)
          CategoryPill(
            label: kind.categoryLabel,
            icon: iconForKind(kind),
            selected: selected == kind,
            onTap: () {
              if (clearQueryOnTap) {
                controller?.clear();
                bloc.add(const QueryChanged(''));
              }
              bloc.add(CategoryToggled(kind));
            },
          ),
      ],
    );
  }
}
