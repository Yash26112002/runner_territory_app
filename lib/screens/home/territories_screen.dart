import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../models/app_models.dart';
import '../../providers/auth_notifier.dart';

class TerritoriesScreen extends StatelessWidget {
  const TerritoriesScreen({super.key});

  static final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        Provider.of<AuthNotifier>(context, listen: false).userToken;

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title:
            const Text('My Territories', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined,
                color: Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Go track a run to claim territory!')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Territory>>(
          stream: _db.streamUserTerritories(currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final territories = snapshot.data ?? [];
            final double totalArea =
                territories.fold(0, (sum, t) => sum + t.areaSqKm);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Empire',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalArea.toStringAsFixed(2)} km²',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
                if (territories.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                            'You don\'t own any territories yet. Go claim some!'),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildTerritoryCard(context, territories[index]);
                      },
                      childCount: territories.length,
                    ),
                  ),
              ],
            );
          }),
    );
  }

  Widget _buildTerritoryCard(BuildContext context, Territory territory) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        // border: isChallenged
        //     ? Border.all(
        //         color: AppTheme.errorRed.withValues(alpha: 0.5), width: 1.5)
        //     : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Territory Details coming soon!')),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Map Placeholder Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.map_rounded,
                      color: AppTheme.primaryOrange,
                      size: 32,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Territory Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Territory', // Name can be added to model later
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.crop_square,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${territory.areaSqKm.toStringAsFixed(2)} km²',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            _formatHeldSince(territory.createdAt),
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Badge if challenged
                // if (isChallenged) ...[
                //   const SizedBox(width: 12),
                //   Container(
                //     padding:
                //         const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                //     decoration: BoxDecoration(
                //       color: AppTheme.errorRed,
                //       borderRadius: BorderRadius.circular(8),
                //     ),
                //     child: const Text(
                //       'Defend!',
                //       style: TextStyle(
                //         color: Colors.white,
                //         fontSize: 10,
                //         fontWeight: FontWeight.bold,
                //       ),
                //     ),
                //   ),
                // ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatHeldSince(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return 'Held ${diff.inDays}d';
    if (diff.inHours > 0) return 'Held ${diff.inHours}h';
    return 'Held ${diff.inMinutes}m';
  }
}
