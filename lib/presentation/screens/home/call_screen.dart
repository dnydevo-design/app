import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Overlay screen for incoming and active UDP Voice Calls
class CallScreen extends StatefulWidget {
  final String peerName;
  final String peerIp;
  final bool isIncoming;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onEnd;

  const CallScreen({
    super.key,
    required this.peerName,
    required this.peerIp,
    required this.isIncoming,
    required this.onAccept,
    required this.onDecline,
    required this.onEnd,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isCallActive = false;

  @override
  void initState() {
    super.initState();
    _isCallActive = !widget.isIncoming;
    
    _pulseController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _acceptCall() {
    setState(() => _isCallActive = true);
    widget.onAccept();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Header
            Column(
              children: [
                Text(
                  _isCallActive ? 'Ongoing Call' : (widget.isIncoming ? 'Incoming Call' : 'Calling...'),
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.peerName,
                  style: AppTextStyles.headlineLarge.copyWith(fontSize: 32, color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.peerIp,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
                ),
              ],
            ),

            // Pulsing Avatar
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isCallActive 
                            ? AppColors.primary.withOpacity(0.3 * _pulseController.value)
                            : AppColors.success.withOpacity(0.4 * _pulseController.value),
                        blurRadius: 50 * _pulseController.value,
                        spreadRadius: 20 * _pulseController.value,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: AppColors.surfaceDark,
                    child: Icon(
                      Icons.person_rounded,
                      size: 80,
                      color: AppColors.onSurfaceDark.withOpacity(0.5),
                    ),
                  ),
                );
              },
            ),

            // Call Duration (Placeholder for active call)
            if (_isCallActive)
              Text(
                '00:00', // Real implementation would use a timer
                style: AppTextStyles.headlineMedium.copyWith(color: Colors.white),
              )
            else
              const SizedBox(height: 30), // Padding

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: widget.isIncoming && !_isCallActive 
                    ? MainAxisAlignment.spaceAround 
                    : MainAxisAlignment.center,
                children: [
                  if (widget.isIncoming && !_isCallActive)
                    _buildActionButton(
                      icon: Icons.call_end_rounded,
                      color: AppColors.error,
                      onPressed: () {
                        widget.onDecline();
                        Navigator.pop(context);
                      },
                    ),
                    
                  if (widget.isIncoming && !_isCallActive)
                    _buildActionButton(
                      icon: Icons.call_rounded,
                      color: AppColors.success,
                      onPressed: _acceptCall,
                    ),

                  if (_isCallActive || !widget.isIncoming)
                    _buildActionButton(
                      icon: Icons.call_end_rounded,
                      color: AppColors.error,
                      onPressed: () {
                        widget.onEnd();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 36),
      ),
    );
  }
}
