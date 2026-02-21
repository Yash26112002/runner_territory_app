import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../models/app_models.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_notifier.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Global Leaderboard',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filters coming soon!')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<UserProfile>>(
          stream: _db.streamLeaderboard(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No runners yet. Go for a run!'));
            }

            final runners = snapshot.data!;
            final currentUserId =
                Provider.of<AuthNotifier>(context, listen: false).userToken;

            return Column(
              children: [
                // Top 3 Podium
                _buildPodium(runners),

                const Divider(height: 1),

                // List of remaining runners
                if (runners.length > 3)
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: runners.length - 3, // Skip top 3
                      itemBuilder: (context, index) {
                        final int rank = index + 4;
                        final runner = runners[index + 3];
                        return _buildLeaderboardTile(
                            runner, rank, currentUserId);
                      },
                    ),
                  ),
              ],
            );
          }),
    );
  }

  Widget _buildPodium(List<UserProfile> runners) {
    if (runners.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (runners.length > 1)
            _buildPodiumSpot(runners[1], 2, 90, Colors.grey[400]!),
          // 1st Place
          if (runners.isNotEmpty)
            _buildPodiumSpot(
                runners[0], 1, 120, const Color(0xFFFFD700)), // Gold
          // 3rd Place
          if (runners.length > 2)
            _buildPodiumSpot(
                runners[2], 3, 70, const Color(0xFFCD7F32)), // Bronze
        ],
      ),
    );
  }

  Widget _buildPodiumSpot(
      UserProfile runner, int rank, double height, Color medalColor) {
    final String avatarText = runner.displayName.isNotEmpty
        ? runner.displayName.substring(0, 1).toUpperCase()
        : '?';

    final String firstName = runner.displayName.split(' ').first;

    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: medalColor.withValues(alpha: 0.2),
          child: Text(
            avatarText,
            style: TextStyle(
              color: medalColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          firstName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '${runner.totalDistance.toStringAsFixed(1)} km',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: medalColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTile(
      UserProfile runner, int rank, String? currentUserId) {
    final bool isCurrentUser = runner.uid == currentUserId;

    final String avatarText = runner.displayName.isNotEmpty
        ? runner.displayName.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.primaryOrange.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.5))
            : null,
        boxShadow: isCurrentUser
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor:
                  isCurrentUser ? AppTheme.primaryOrange : Colors.grey[200],
              child: Text(
                avatarText,
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          runner.displayName,
          style: TextStyle(
            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: Text(
          '${runner.totalDistance.toStringAsFixed(1)} km',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
