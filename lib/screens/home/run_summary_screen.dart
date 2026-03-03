import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../models/app_models.dart';
import '../../utils/constants.dart';

class RunSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> runData;

  const RunSummaryScreen({super.key, required this.runData});

  @override
  State<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends State<RunSummaryScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    final claimedTerritory =
        widget.runData['claimedTerritory'] as Territory?;
    if (claimedTerritory != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatPace(double distanceKm, int timeSeconds) {
    if (distanceKm < 0.01) return '--:--';
    final minutes = timeSeconds / 60;
    final pace = minutes / distanceKm;
    final pm = pace.floor();
    final ps = ((pace - pm) * 60).round();
    return '$pm:${ps.toString().padLeft(2, '0')}';
  }

  void _shareRun() {
    final distanceKm = widget.runData['distanceKm'] as double? ?? 0.0;
    final timeSeconds = widget.runData['timeSeconds'] as int? ?? 0;
    final claimedTerritory =
        widget.runData['claimedTerritory'] as Territory?;

    String message =
        'I just ran ${distanceKm.toStringAsFixed(2)} km in ${_formatTime(timeSeconds)} with Runner Territory!';
    if (claimedTerritory != null) {
      message +=
          '\nI claimed ${claimedTerritory.areaSqKm.toStringAsFixed(2)} km² of territory!';
    }
    message += '\n\n#RunnerTerritory #Running';
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = widget.runData['distanceKm'] as double? ?? 0.0;
    final timeSeconds = widget.runData['timeSeconds'] as int? ?? 0;
    final claimedTerritory =
        widget.runData['claimedTerritory'] as Territory?;
    final maxSpeedKph = widget.runData['maxSpeedKph'] as double? ?? 0.0;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.backgroundGradient),
          ),

          // Confetti burst on territory claim
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              colors: const [
                Colors.white,
                Colors.yellow,
                Colors.orange,
                Colors.red,
              ],
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  Text(
                    claimedTerritory != null
                        ? 'Territory Claimed!'
                        : 'Run Complete!',
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    claimedTerritory != null
                        ? "You've marked your territory!"
                        : 'Great effort, keep it up!',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Stats card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusXLarge),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          distanceKm.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                        const Text(
                          'KILOMETERS',
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 2,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _statItem(
                              label: 'TIME',
                              value: _formatTime(timeSeconds),
                              icon: Icons.timer_outlined,
                              color: AppTheme.secondaryBlue,
                            ),
                            _statItem(
                              label: 'PACE',
                              value:
                                  '${_formatPace(distanceKm, timeSeconds)}/km',
                              icon: Icons.speed,
                              color: AppTheme.successGreen,
                            ),
                            _statItem(
                              label: 'MAX SPEED',
                              value: '${maxSpeedKph.toStringAsFixed(1)} km/h',
                              icon: Icons.bolt,
                              color: AppTheme.warningYellow,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Territory claim card
                  if (claimedTerritory != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusXLarge),
                        border: Border.all(
                          color:
                              AppTheme.primaryOrange.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flag,
                              color: AppTheme.primaryOrange,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Territory Claimed',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${claimedTerritory.areaSqKm.toStringAsFixed(2)} km² added to your map',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.verified,
                              color: AppTheme.primaryOrange),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Share button
                  OutlinedButton.icon(
                    onPressed: _shareRun,
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text(
                      'Share Run',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusLarge),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Back to dashboard
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppConstants.routeDashboard,
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusLarge),
                      ),
                    ),
                    child: const Text(
                      'Back to Dashboard',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
