import 'package:flutter/material.dart';

class NoModulesScreen extends StatelessWidget {
  const NoModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.extension_off, size: 64, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'No Modules Selected',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "You haven't activated any modules yet.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
