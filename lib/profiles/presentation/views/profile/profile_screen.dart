import 'package:flutter/material.dart';
import 'package:rumbo_mobile_application/shared/presentation/widgets/foundation_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FoundationPage(
      title: 'Perfil y preferencias',
      description: 'Aquí se incorporarán los datos y las preferencias de guiado del visitante.',
      icon: Icons.person_outline,
    );
  }
}
