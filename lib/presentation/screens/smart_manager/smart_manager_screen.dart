import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../widgets/common_widgets.dart';

class SmartManagerScreen extends StatefulWidget {
  const SmartManagerScreen({super.key});

  @override
  State<SmartManagerScreen> createState() => _SmartManagerScreenState();
}

class _SmartManagerScreenState extends State<SmartManagerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Manager'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Storage Clean-up'),
          _buildStorageCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('Extra Tools'),
          _buildToolCard(
            title: 'Private Vault',
            subtitle: 'AES-256 Encrypted secure folder',
            icon: Icons.lock_rounded,
            color: const Color(0xFF9C27B0),
            onTap: () {
              // Production: Navigate to Vault
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.headlineSmall,
      ),
    );
  }

  Widget _buildStorageCard() {
    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-Clean', style: AppTextStyles.headlineMedium),
                    const SizedBox(height: 4),
                    Text('Detects duplicate & junk files', style: AppTextStyles.bodyMedium),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cleaning_services_rounded, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GradientButton(
              text: 'Scan Now',
              icon: Icons.search_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassmorphicCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headlineMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryDark),
            ],
          ),
        ),
      ),
    );
  }
}
