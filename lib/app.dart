import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_info.dart';
import 'features/home/presentation/home_page.dart';

class AghelanApp extends ConsumerWidget {
  const AghelanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomePage(),
    );
  }
}
