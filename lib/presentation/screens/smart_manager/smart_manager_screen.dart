import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/video_converter_service.dart';
import '../../widgets/common_widgets.dart';

class SmartManagerScreen extends StatefulWidget {
  const SmartManagerScreen({super.key});

  @override
  State<SmartManagerScreen> createState() => _SmartManagerScreenState();
}

class _SmartManagerScreenState extends State<SmartManagerScreen> {
  final VideoConverterService _converterService = VideoConverterService();
  bool _isConverting = false;

  void _pickAndConvertVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowCompression: false,
      );

      if (result != null && result.files.single.path != null) {
        final videoFile = File(result.files.single.path!);
        
        setState(() => _isConverting = true);
        
        final outputPath = await _converterService.convertToMp3(videoFile);
        
        setState(() => _isConverting = false);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text('✨ Video converted to MP3 successfully!'),
               backgroundColor: AppColors.success,
               behavior: SnackBarBehavior.floating,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               action: SnackBarAction(
                 label: 'VIEW', 
                 textColor: Colors.white,
                 onPressed: () {
                   // Production: Open the file or show in file manager
                   debugPrint('Saved to: $outputPath');
                 }
               ),
             )
           );
        }
      }
    } catch (e) {
      setState(() => _isConverting = false);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('Failed: $e'),
               backgroundColor: AppColors.error,
               behavior: SnackBarBehavior.floating,
             )
         );
      }
    }
  }

  @override
  void dispose() {
    _converterService.cancelConversions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Manager'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle('Storage Clean-up'),
              _buildStorageCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('Extra Tools'),
              _buildToolCard(
                title: 'Video to MP3 Converter',
                subtitle: 'Extract high-quality audio from video files',
                icon: Icons.audio_file_rounded,
                color: const Color(0xFFE91E63),
                onTap: _pickAndConvertVideo,
              ),
              const SizedBox(height: 12),
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
          
          if (_isConverting)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Card(
                  color: AppColors.surfaceDark,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Extracting Audio...',
                          style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This may take a minute based on video length.',
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                           onPressed: () {
                              _converterService.cancelConversions();
                              setState(() => _isConverting = false);
                           }, 
                           child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
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
