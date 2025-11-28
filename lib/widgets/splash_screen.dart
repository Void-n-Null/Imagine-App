import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _sparkleController;
  late AnimationController _fadeController;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Logo entrance animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    
    // Sparkle/glow animation
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );
    
    // Fade out animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _startAnimationSequence();
  }
  
  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _logoController.forward();
    
    await Future.delayed(const Duration(milliseconds: 400));
    _sparkleController.forward();
    
    await Future.delayed(const Duration(milliseconds: 1200));
    await _fadeController.forward();
    
    widget.onComplete();
  }
  
  @override
  void dispose() {
    _logoController.dispose();
    _sparkleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController, _sparkleController, _fadeController]),
      builder: (context, child) {
        return Opacity(
          opacity: 1.0 - _fadeController.value,
          child: Container(
            color: AppColors.background,
            child: Stack(
              children: [
                // Animated background particles
                ..._buildParticles(),
                
                // Glow effect behind logo
                Center(
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 200 + (_glowAnimation.value * 100),
                        height: 200 + (_glowAnimation.value * 100),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primaryBlue.withValues(alpha: 0.3 * _glowAnimation.value),
                              AppColors.primaryBlue.withValues(alpha: 0.1 * _glowAnimation.value),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Main logo
                Center(
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: _buildLogo(),
                    ),
                  ),
                ),
                
                // Sparkle effects
                ..._buildSparkles(),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentYellow.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 50,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'lib/assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if image not found
            return Container(
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 60,
                color: AppColors.accentYellow,
              ),
            );
          },
        ),
      ),
    );
  }
  
  List<Widget> _buildParticles() {
    final random = math.Random(42);
    return List.generate(20, (index) {
      final startX = random.nextDouble() * MediaQuery.of(context).size.width;
      final startY = random.nextDouble() * MediaQuery.of(context).size.height;
      final size = 2.0 + random.nextDouble() * 4;
      final delay = random.nextDouble();
      
      return Positioned(
        left: startX,
        top: startY,
        child: AnimatedBuilder(
          animation: _sparkleController,
          builder: (context, child) {
            final progress = ((_sparkleController.value - delay) * 2).clamp(0.0, 1.0);
            final opacity = math.sin(progress * math.pi) * 0.6;
            
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index % 2 == 0 ? AppColors.accentYellow : AppColors.primaryBlue,
                ),
              ),
            );
          },
        ),
      );
    });
  }
  
  List<Widget> _buildSparkles() {
    return List.generate(3, (index) {
      final angle = (index * 120) * math.pi / 180;
      final radius = 80.0;
      
      return Center(
        child: AnimatedBuilder(
          animation: _sparkleController,
          builder: (context, child) {
            final progress = _sparkleController.value;
            final expandedRadius = radius + (progress * 40);
            final opacity = math.sin(progress * math.pi);
            final rotation = progress * math.pi * 2;
            
            return Transform.translate(
              offset: Offset(
                math.cos(angle + rotation) * expandedRadius,
                math.sin(angle + rotation) * expandedRadius,
              ),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: _buildSparkleIcon(index),
              ),
            );
          },
        ),
      );
    });
  }
  
  Widget _buildSparkleIcon(int index) {
    final colors = [AppColors.accentYellow, AppColors.brightYellow, AppColors.primaryBlue];
    final sizes = [24.0, 18.0, 20.0];
    
    return Icon(
      Icons.auto_awesome,
      color: colors[index],
      size: sizes[index],
    );
  }
}

