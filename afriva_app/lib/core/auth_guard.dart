import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';

/// Ensures the viewer is logged in. Opens the login screen if needed and
/// resolves to true once a session exists.
Future<bool> requireLogin(BuildContext context) async {
  final auth = context.read<AuthState>();
  if (auth.isLoggedIn) return true;
  await context.push<bool>('/login');
  return auth.isLoggedIn;
}
