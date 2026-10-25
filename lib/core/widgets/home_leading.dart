import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App bar leading button for pages that can be opened directly from a link: a back arrow
/// when there is a page to go back to, otherwise a Home button so the user is never stuck.
Widget? backOrHome(BuildContext context) {
  if (context.canPop()) return null;
  return IconButton(icon: const Icon(Icons.home_outlined), tooltip: 'Home', onPressed: () => context.go('/home'));
}
