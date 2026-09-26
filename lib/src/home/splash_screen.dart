import 'package:flutter/material.dart';

import 'home_screen.dart';

/// Launch intro: logo fades/scales in with a diagonal shine sweep (~1.8s),
/// then navigates home. (flutter_native_splash shows the static logo first.)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _shine;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.45));
    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _shine = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 0.95, curve: Curves.easeInOut)),
    );
    _ctrl.forward();
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: ClipOval(
                child: SizedBox(
                  width: 168,
                  height: 168,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                    Image.asset(
                      'assets/logo/eviee-mark.webp',
                      fit: BoxFit.contain,
                    ),
                    // Moving highlight, clipped to the logo's alpha.
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (rect) {
                        final p = _shine.value;
                        return LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: const [
                            Color(0x00FFFFFF),
                            Color(0x00FFFFFF),
                            Color(0xE6FFFFFF),
                            Color(0x00FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                          stops: [
                            (p - 0.30).clamp(0.0, 1.0),
                            (p - 0.10).clamp(0.0, 1.0),
                            p.clamp(0.0, 1.0),
                            (p + 0.10).clamp(0.0, 1.0),
                            (p + 0.30).clamp(0.0, 1.0),
                          ],
                          transform: const GradientRotation(0.45),
                        ).createShader(rect);
                      },
                      child: Image.asset(
                        'assets/logo/eviee-mark.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
