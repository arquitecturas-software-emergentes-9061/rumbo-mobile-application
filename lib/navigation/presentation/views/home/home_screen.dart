import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rumbo_mobile_application/shared/presentation/widgets/foundation_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: FoundationPage(
            title: 'Bienvenido a Rumbo',
            description:
                'La base de la aplicación móvil está lista para incorporar los flujos de orientación de la clínica.',
            icon: Icons.navigation_outlined,
          ),
        ),
        if (kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton.icon(
              onPressed: () => context.push('/developer/ble'),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Diagnóstico BLE'),
            ),
          ),
      ],
    );
  }
}
