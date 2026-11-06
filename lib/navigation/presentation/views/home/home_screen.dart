import 'package:flutter/material.dart';
import 'package:rumbo_mobile_application/shared/presentation/widgets/foundation_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FoundationPage(
      title: 'Bienvenido a Rumbo',
      description: 'La base de la aplicación móvil está lista para incorporar los flujos de orientación de la clínica.',
      icon: Icons.navigation_outlined,
    );
  }
}
