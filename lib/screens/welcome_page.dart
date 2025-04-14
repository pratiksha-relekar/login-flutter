import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  
  Timer? _pulseTimer;
  bool _isPulsing = false;
  double _backgroundAnimValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _rotateAnimation = Tween<double>(begin: 0.05, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _controller.forward();
    
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _backgroundAnimValue += 0.01;
        });
      } else {
        timer.cancel();
      }
    });
    
    _startPulseEffect();
  }

  void _startPulseEffect() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _isPulsing = !_isPulsing;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade800,
              Colors.indigo.shade300,
            ],
            stops: [0.3 + 0.1 * math.sin(_backgroundAnimValue), 0.9],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -50 + 10 * math.sin(_backgroundAnimValue * 2),
                left: -50 + 10 * math.cos(_backgroundAnimValue * 3),
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1 + 0.05 * math.sin(_backgroundAnimValue)),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Positioned(
                bottom: -80 + 15 * math.cos(_backgroundAnimValue),
                right: -80 + 15 * math.sin(_backgroundAnimValue * 2),
                child: Container(
                  height: 300,
                  width: 300,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1 + 0.05 * math.cos(_backgroundAnimValue)),
                    borderRadius: BorderRadius.circular(150),
                  ),
                ),
              ),
              
              ...List.generate(10, (index) {
                final size = 8.0 + index * 2.0;
                final speed = 0.02 + index * 0.005;
                final delay = index * 0.2;
                final x = math.sin(_backgroundAnimValue * speed + delay) * 150 + MediaQuery.of(context).size.width / 2;
                final y = math.cos(_backgroundAnimValue * speed + delay) * 200 + MediaQuery.of(context).size.height / 2;
                return Positioned(
                  left: x,
                  top: y,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              
              Center(
                child: FadeTransition(
                  opacity: _fadeInAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: RotationTransition(
                        turns: _rotateAnimation,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet,
                                      color: Colors.indigo.shade800,
                                      size: 35,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ShimmerText(
                                    text: 'MyMoneyMate',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.2),
                                          offset: const Offset(1, 1),
                                          blurRadius: 5,
                                        ),
                                        Shadow(
                                          color: Colors.indigo.withOpacity(0.3),
                                          offset: const Offset(2, 2),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                transform: Matrix4.translationValues(0, math.sin(_backgroundAnimValue * 1.5) * 5, 0),
                                child: Text(
                                  'Welcome!',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 1000),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2 + 0.1 * math.sin(_backgroundAnimValue * 2)),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.indigo.withOpacity(0.1 + 0.05 * math.sin(_backgroundAnimValue * 3)),
                                      blurRadius: 15,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Track smart. Save better.\nLive richer — with MyMoneyMate.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white.withOpacity(0.95),
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              AnimatedOpacity(
                                opacity: 0.7 + 0.3 * math.sin(_backgroundAnimValue),
                                duration: const Duration(milliseconds: 500),
                                child: Text(
                                  'Your all-in-one companion to track income, manage expenses, and grow your savings effortlessly.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.8),
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                              const SizedBox(height: 48),
                              
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                transform: Matrix4.translationValues(0, _isPulsing ? -3 : 0, 0),
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(context, '/login');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.indigo,
                                    minimumSize: const Size(double.infinity, 65),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: _isPulsing ? 8 : 3,
                                  ),
                                  child: const Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                transform: Matrix4.translationValues(0, _isPulsing ? 3 : 0, 0),
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(context, '/signup');
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 65),
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(_isPulsing ? 1.0 : 0.8),
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text(
                                    'SIGN UP',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  
  const ShimmerText({
    Key? key,
    required this.text,
    required this.style,
  }) : super(key: key);

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  
  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }
  
  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.white.withOpacity(0.8),
                Colors.white,
                Colors.white.withOpacity(0.8),
              ],
              stops: [
                _shimmerController.value - 0.3,
                _shimmerController.value,
                _shimmerController.value + 0.3,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              tileMode: TileMode.repeated,
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.style,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
} 