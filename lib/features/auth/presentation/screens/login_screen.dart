import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../controllers/auth_controller.dart';

// --- AMBIENT CANVAS PARTICLE ENGINE ---
class GoldParticle {
  double x;
  double y;
  double speed;
  double size;
  double opacity;
  double angle;

  GoldParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.angle,
  });

  void update(double width, double height) {
    y -= speed; // Drifting upwards
    x += math.sin(angle) * 0.5; // Slight sway
    angle += 0.05;
    if (y < -10) {
      y = height + 10;
      x = math.Random().nextDouble() * width;
    }
  }
}

class ParticlePainter extends CustomPainter {
  final List<GoldParticle> particles;
  final Listenable repaint;

  ParticlePainter(this.particles, this.repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      paint.color = AppTheme.primaryGold.withOpacity(p.opacity);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}

// --- LOGIN SCREEN WITH INTERACTIVE GATE & OTP TRIGGER ---
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Interactive Gate Animation Controllers
  late AnimationController _gateController;
  late AnimationController _medallionController;
  late AnimationController _flashController;
  late AnimationController _particleAnimController;

  late Animation<double> _gateLeftSlide;
  late Animation<double> _gateRightSlide;
  late Animation<double> _medallionScale;
  late Animation<double> _medallionRotation;
  late Animation<double> _flashOpacity;

  bool _isGateOpen = false;
  final List<GoldParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    // 1. Gate Slide controller (2 doors sliding out)
    _gateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _gateLeftSlide = Tween<double>(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(parent: _gateController, curve: Curves.easeInOutQuart),
    );
    _gateRightSlide = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gateController, curve: Curves.easeInOutQuart),
    );

    // 2. Medallion Spin & scale controller
    _medallionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _medallionScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _medallionController, curve: Curves.easeInOutBack));

    _medallionRotation = Tween<double>(begin: 0.0, end: 4 * math.pi).animate(
      CurvedAnimation(parent: _medallionController, curve: Curves.easeInOutBack),
    );

    // 3. Dynamic Flash controller for seamless scene transition
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _flashController, curve: Curves.easeIn));

    // 4. Background Particle loop
    _particleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initParticles());
  }

  void _initParticles() {
    final size = MediaQuery.of(context).size;
    final rand = math.Random();
    for (int i = 0; i < 40; i++) {
      _particles.add(GoldParticle(
        x: rand.nextDouble() * size.width,
        y: rand.nextDouble() * size.height,
        speed: 0.5 + rand.nextDouble() * 1.5,
        size: 1.5 + rand.nextDouble() * 3.0,
        opacity: 0.2 + rand.nextDouble() * 0.6,
        angle: rand.nextDouble() * 2 * math.pi,
      ));
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _gateController.dispose();
    _medallionController.dispose();
    _flashController.dispose();
    _particleAnimController.dispose();
    super.dispose();
  }

  // Action: User clicks Wax Seal Medallion to Open Gate
  void _triggerUnlock() async {
    if (_isGateOpen) return;
    
    // Play Medallion animation
    _medallionController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Trigger transition flash
    _flashController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    
    // Slide gates open
    _gateController.forward().then((_) {
      setState(() {
        _isGateOpen = true;
      });
    });
  }

  // Action: Skip interactive opening gates
  void _skipGate() {
    setState(() {
      _isGateOpen = true;
    });
  }

  Future<void> _submitPhoneNumber() async {
    if (!_formKey.currentState!.validate()) return;
    
    final phone = _phoneController.text.trim();
    
    // Format if needed
    ref.read(authControllerProvider.notifier).requestOTP(phone).then((_) {
      context.push('/otp', extra: phone);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Background particles update loop
    for (var p in _particles) {
      p.update(size.width, size.height);
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Particle Canvas Background
          Positioned.fill(
            child: Container(
              color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
              child: CustomPaint(
                painter: ParticlePainter(_particles, _particleAnimController),
              ),
            ),
          ),

          // 2. Underlying Login Form (revealed behind the gates)
          if (_isGateOpen)
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/logo_placeholder.png',
                          height: 80,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 80,
                            width: 80,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primaryGold, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.delivery_dining_rounded,
                              size: 48,
                              color: AppTheme.primaryGold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'RiderFlow',
                          style: theme.textTheme.displayLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Courier Franchise Management System',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'Phone Login',
                          style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _phoneController,
                          labelText: 'Mobile Number',
                          hintText: 'Enter 10-digit number',
                          prefixIcon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Phone number is required';
                            }
                            if (val.length < 10) {
                              return 'Enter a valid 10-digit phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        CustomButton(
                          text: 'Get OTP',
                          isLoading: authState.isLoading,
                          onPressed: _submitPhoneNumber,
                        ),
                        const SizedBox(height: 24),
                        // Quick presentation helper to switch user profiles instantly
                        _buildPresentationHelpers(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 3. Sliding Gate Doors overlay (Left & Right)
          if (!_isGateOpen) ...[
            // Left Gate
            AnimatedBuilder(
              animation: _gateLeftSlide,
              builder: (context, child) {
                return Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: size.width / 2,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..translate(_gateLeftSlide.value * (size.width / 2)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141724) : Colors.grey.shade100,
                        border: Border(
                          right: BorderSide(
                            color: AppTheme.primaryGold.withOpacity(0.3),
                            width: 2.0,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -2,
                            top: size.height * 0.35,
                            child: _buildGateOrnaments(isLeft: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Right Gate
            AnimatedBuilder(
              animation: _gateRightSlide,
              builder: (context, child) {
                return Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: size.width / 2,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..translate(_gateRightSlide.value * (size.width / 2)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141724) : Colors.grey.shade100,
                        border: Border(
                          left: BorderSide(
                            color: AppTheme.primaryGold.withOpacity(0.3),
                            width: 2.0,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: -2,
                            top: size.height * 0.35,
                            child: _buildGateOrnaments(isLeft: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Medallion Unlock Button (Centered)
            Align(
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: _medallionController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _medallionScale.value,
                    child: Transform.rotate(
                      angle: _medallionRotation.value,
                      child: GestureDetector(
                        onTap: _triggerUnlock,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0F111A),
                            border: Border.all(color: AppTheme.primaryGold, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGold.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.vpn_key_rounded,
                              color: AppTheme.primaryGold,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Medallion Callout Text
            Positioned(
              top: size.height * 0.58,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_gateController),
                child: Column(
                  children: [
                    Text(
                      'TAP TO UNLOCK GATE',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.primaryGold,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RiderFlow Coupe',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Skip Button (Bypass 3D Gate)
            Positioned(
              top: 48,
              right: 20,
              child: FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_gateController),
                child: TextButton(
                  onPressed: _skipGate,
                  child: Text(
                    'Skip',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.primaryGold.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // 4. White/Gold Flash Overlay for seamless scene updates
          AnimatedBuilder(
            animation: _flashController,
            builder: (context, child) {
              return Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.white.withOpacity(_flashOpacity.value),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Ornaments drawn on the doors
  Widget _buildGateOrnaments({required bool isLeft}) {
    return Container(
      width: 40,
      height: 200,
      alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
      child: CustomPaint(
        painter: GateOrnamentPainter(isLeft: isLeft),
        size: const Size(40, 200),
      ),
    );
  }

  // Quick helper in the login UI to switch user profiles instantly during review
  Widget _buildPresentationHelpers() {
    return Container(
      margin: const EdgeInsets.top(48.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🔐 Review Sandbox Quick Roles',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                label: const Text('Arjun (Rider)'),
                onPressed: () => _quickLogin('9876543210', 'rdr_1', UserRole.rider),
              ),
              ActionChip(
                label: const Text('Siddharth (Rider)'),
                onPressed: () => _quickLogin('8765432109', 'rdr_2', UserRole.rider),
              ),
              ActionChip(
                label: const Text('Manager Raj'),
                onPressed: () => _quickLogin('9988776655', 'mgr_1', UserRole.manager),
              ),
              ActionChip(
                label: const Text('Owner Maya'),
                onPressed: () => _quickLogin('9000000000', 'own_1', UserRole.owner),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _quickLogin(String phone, String uid, UserRole role) async {
    final updatedUser = UserModel(
      uid: uid,
      name: role == UserRole.owner
          ? 'Maya (Owner)'
          : (role == UserRole.manager ? 'Manager Raj' : (uid == 'rdr_1' ? 'Arjun Kumar' : 'Siddharth Nair')),
      mobileNumber: phone,
      role: role,
      companyId: 'co_test',
      branchId: 'br_test',
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    );
    await ref.read(authControllerProvider.notifier).testSwitchUser(updatedUser);
  }
}

// Painter for physical card ornament patterns
class GateOrnamentPainter extends CustomPainter {
  final bool isLeft;
  GateOrnamentPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryGold.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    if (isLeft) {
      path.moveTo(size.width, 0);
      path.quadraticBezierTo(0, size.height * 0.25, size.width, size.height * 0.5);
      path.quadraticBezierTo(0, size.height * 0.75, size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.quadraticBezierTo(size.width, size.height * 0.25, 0, size.height * 0.5);
      path.quadraticBezierTo(size.width, size.height * 0.75, 0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
