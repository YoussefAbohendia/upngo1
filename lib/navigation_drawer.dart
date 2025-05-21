import 'package:flutter/material.dart';
import 'auth_service.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({
    Key? key,
    required this.currentRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildHeader(context),
          _buildMenuItems(context),
          const Spacer(),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService.getCurrentUserEmail(),
      builder: (context, snapshot) {
        final email = snapshot.data ?? 'User';
        return UserAccountsDrawerHeader(
          accountName: FutureBuilder<String?>(
            future: AuthService.getCurrentUserId().then((id) async {
              if (id != null) {
                final profile = await AuthService.getUserProfile(id);
                return profile?['display_name'];
              }
              return null;
            }),
            builder: (context, snapshot) {
              return Text(snapshot.data ?? 'User');
            },
          ),
          accountEmail: Text(email),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: const Icon(
              Icons.person,
              size: 40,
              color: Colors.white,
            ),
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
          ),
        );
      },
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMenuItem(
          context,
          title: 'Home',
          icon: Icons.home_outlined,
          route: '/home',
        ),
        _buildMenuItem(
          context,
          title: 'Alarms',
          icon: Icons.alarm_outlined,
          route: '/alarms',
        ),
        _buildMenuItem(
          context,
          title: 'Sleep History',
          icon: Icons.history_outlined,
          route: '/history',
        ),
        _buildMenuItem(
          context,
          title: 'Statistics',
          icon: Icons.bar_chart_outlined,
          route: '/statistics',
        ),
        _buildMenuItem(
          context,
          title: 'Settings',
          icon: Icons.settings_outlined,
          route: '/settings',
        ),
        const Divider(),
        _buildMenuItem(
          context,
          title: 'Help & Support',
          icon: Icons.help_outline,
          route: '/help',
        ),
      ],
    );
  }

  Widget _buildMenuItem(
      BuildContext context, {
        required String title,
        required IconData icon,
        required String route,
      }) {
    final isSelected = currentRoute == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      selected: isSelected,
      onTap: () {
        // Close drawer first
        Navigator.pop(context);

        // Only navigate if not already on this route
        if (currentRoute != route) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              // Show confirmation dialog
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              // If confirmed
              if (result == true) {
                // Close drawer first
                Navigator.pop(context);

                // Logout and navigate to login screen
                await AuthService.logout();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            'UpNGo v1.0.0',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            '© 2025 UpNGo',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}