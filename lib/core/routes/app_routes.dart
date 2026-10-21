import 'package:flutter/material.dart';

import '../../admin/admin_shell.dart';
import '../../auth/login_page.dart';
import '../../user/user_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String admin = '/admin';
  static const String user = '/user';

  static Map<String, WidgetBuilder> get routes => <String, WidgetBuilder>{
    login: (BuildContext context) => const LoginPage(),
    admin: (BuildContext context) => const AdminShell(),
    user: (BuildContext context) => const UserShell(),
  };

  /// Opens a route and clears the whole navigation stack,
  /// so Back cannot return to the previous screen.
  static void goAndClearStack(BuildContext context, String routeName) {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(routeName, (Route<dynamic> route) => false);
  }
}
