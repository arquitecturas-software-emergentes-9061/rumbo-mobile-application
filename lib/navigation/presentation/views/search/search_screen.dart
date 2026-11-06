import 'package:flutter/material.dart';
import 'package:rumbo_mobile_application/shared/presentation/widgets/foundation_page.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FoundationPage(
      title: 'Buscar destino',
      description: 'Aquí se incorporará la búsqueda del directorio cuando se implemente su historia.',
      icon: Icons.search,
    );
  }
}
