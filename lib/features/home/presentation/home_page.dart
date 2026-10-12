import 'package:flutter/material.dart';

import '../../../core/constants/app_info.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppInfo.name)),
      body: const Center(child: Text(AppInfo.nameFa)),
    );
  }
}
