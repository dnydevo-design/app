import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../bloc/locale/locale_cubit.dart';
import '../../bloc/theme/theme_cubit.dart';
import '../../widgets/common_widgets.dart';

/// Profile screen with settings and statistics.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile header
              _buildProfileHeader(context, isDark),
              const SizedBox(height: 24),
              // Statistics
              _buildStatisticsRow(context),
              const SizedBox(height: 24),
              // Settings
              _buildSettingsSection(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, bool isDark) {
    return GlassmorphicCard(
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Fast Share User',
            style: AppTextStyles.headlineMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to edit your profile',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(context, 'Sent', '0', Icons.upload_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard(context, 'Received', '0', Icons.download_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard(context, 'Total', '0 B', Icons.data_usage_rounded)),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.settings_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Settings',
              style: AppTextStyles.headlineSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Dark mode toggle
        GlassmorphicCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              'Dark Mode',
              style: AppTextStyles.bodyLarge.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              isDark ? 'True Black (OLED)' : 'Light Mode',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            trailing: Switch.adaptive(
              value: isDark,
              onChanged: (_) => context.read<ThemeCubit>().toggle(),
              activeColor: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Language toggle
        GlassmorphicCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.translate_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              'Language',
              style: AppTextStyles.bodyLarge.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            subtitle: BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) {
                return Text(
                  locale.languageCode == 'ar' ? 'العربية' : 'English',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                );
              },
            ),
            trailing: TextButton(
              onPressed: () => context.read<LocaleCubit>().toggle(),
              child: const Text('Switch'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // About
        GlassmorphicCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              'About Fast Share',
              style: AppTextStyles.bodyLarge.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              'Version 1.0.0',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ],
    );
  }
}
