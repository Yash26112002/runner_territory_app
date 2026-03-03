import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const ShimmerLoading.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
  }) : shapeBorder = const RoundedRectangleBorder();

  const ShimmerLoading.circular({
    super.key,
    required this.width,
    required this.height,
    this.shapeBorder = const CircleBorder(),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: Colors.grey[400]!,
          shape: shapeBorder,
        ),
      ),
    );
  }
}

class LeaderboardShimmer extends StatelessWidget {
  const LeaderboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Podium Shimmer
        Container(
          height: 250,
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildPodiumShimmerSpot(90),
              _buildPodiumShimmerSpot(120),
              _buildPodiumShimmerSpot(70),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const ShimmerLoading.circular(width: 40, height: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerLoading.rectangular(
                            height: 16,
                            width: MediaQuery.of(context).size.width * 0.4),
                        const SizedBox(height: 8),
                        ShimmerLoading.rectangular(
                            height: 12,
                            width: MediaQuery.of(context).size.width * 0.2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumShimmerSpot(double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const ShimmerLoading.circular(width: 60, height: 60),
        const SizedBox(height: 8),
        const ShimmerLoading.rectangular(height: 14, width: 50),
        const SizedBox(height: 8),
        ShimmerLoading.rectangular(height: height, width: 60),
      ],
    );
  }
}

class SocialShimmer extends StatelessWidget {
  const SocialShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const ShimmerLoading.circular(width: 45, height: 45),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading.rectangular(
                        height: 14,
                        width: MediaQuery.of(context).size.width * 0.4),
                    const SizedBox(height: 6),
                    ShimmerLoading.rectangular(
                        height: 10,
                        width: MediaQuery.of(context).size.width * 0.2),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ShimmerLoading.rectangular(
                height: 100, width: double.infinity),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ShimmerLoading.rectangular(height: 20, width: 60),
                SizedBox(width: 16),
                ShimmerLoading.rectangular(height: 20, width: 60),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
