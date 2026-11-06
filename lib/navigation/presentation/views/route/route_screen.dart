import 'package:flutter/material.dart';
import 'package:rumbo_mobile_application/shared/presentation/widgets/foundation_page.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FoundationPage(
      title: 'Tu ruta',
      description: 'Aquí se incorporarán el mapa y el guiado cuando se implementen sus historias.',
      icon: Icons.alt_route,
    );
  }
}
