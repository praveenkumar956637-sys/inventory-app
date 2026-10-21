import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/app_card.dart';
import '../widgets/state_views.dart';
import '../widgets/status_chip.dart';

const Color _greyTint = Color(0x146B7280);

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final AuthService _authService = AuthService();
  late Stream<List<UserModel>> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = _authService.streamUsers();
  }

  void _retry() {
    setState(() => _usersStream = _authService.streamUsers());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: _usersStream,
      builder: (BuildContext context, AsyncSnapshot<List<UserModel>> snapshot) {
        if (snapshot.hasError) {
          return ErrorStateView(
            message: AppException.messageOf(snapshot.error!),
            onRetry: _retry,
          );
        }
        if (!snapshot.hasData) {
          return const LoadingView();
        }
        final List<UserModel> users = snapshot.data!;
        if (users.isEmpty) {
          return const EmptyStateView(
            icon: Icons.people_outline,
            title: 'No users found',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return _buildSummary(users);
            }
            return _UserCard(user: users[index - 1]);
          },
        );
      },
    );
  }

  Widget _buildSummary(List<UserModel> users) {
    final int admins = users.where((UserModel u) => u.isAdmin).length;
    final int staff = users.where((UserModel u) => u.isStaff).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _Stat(label: 'Total users', value: users.length),
              ),
              Container(height: 32, width: 1, color: AppColors.border),
              Expanded(
                child: _Stat(label: 'Admins', value: admins),
              ),
              Container(height: 32, width: 1, color: AppColors.border),
              Expanded(
                child: _Stat(label: 'Staff', value: staff),
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'All Users'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlack,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final String displayName = user.name.isEmpty ? 'Unnamed' : user.name;
    final String initial = displayName[0].toUpperCase();

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: user.active ? AppColors.darkBlack : AppColors.blackTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: user.active ? AppColors.white : AppColors.darkBlack,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkBlack,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    StatusChip(
                      label: user.roleLabel,
                      color: user.isAdmin
                          ? AppColors.darkBlack
                          : AppColors.textGrey,
                      tint: user.isAdmin ? AppColors.blackTint : _greyTint,
                    ),
                    StatusChip(
                      label: user.active ? 'Active' : 'Inactive',
                      color: user.active
                          ? AppColors.green
                          : AppColors.primaryRed,
                      tint: user.active
                          ? AppColors.greenTint
                          : AppColors.redTint,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
