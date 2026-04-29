import 'package:flutter/material.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final double? elevation;
  final ShapeBorder? shape;
  final Duration animationDuration;
  final Curve animationCurve;

  const AnimatedCard({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeInOut,
  }) : super(key: key);

  @override
  _AnimatedCardState createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.animationCurve,
    ));

    _elevationAnimation = Tween<double>(
      begin: widget.elevation ?? 4.0,
      end: (widget.elevation ?? 4.0) + 8.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.animationCurve,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              elevation: _elevationAnimation.value,
              color: widget.backgroundColor,
              shape: widget.shape,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class SlidingCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Duration slideDuration;
  final Duration delayDuration;
  final SlideDirection slideDirection;
  final double slideDistance;

  const SlidingCard({
    Key? key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.slideDuration = const Duration(milliseconds: 600),
    this.delayDuration = Duration.zero,
    this.slideDirection = SlideDirection.left,
    this.slideDistance = 50.0,
  }) : super(key: key);

  @override
  _SlidingCardState createState() => _SlidingCardState();
}

class _SlidingCardState extends State<SlidingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.slideDuration,
      vsync: this,
    );

    Offset beginOffset;
    switch (widget.slideDirection) {
      case SlideDirection.left:
        beginOffset = Offset(-widget.slideDistance / 100, 0);
        break;
      case SlideDirection.right:
        beginOffset = Offset(widget.slideDistance / 100, 0);
        break;
      case SlideDirection.up:
        beginOffset = Offset(0, -widget.slideDistance / 100);
        break;
      case SlideDirection.down:
        beginOffset = Offset(0, widget.slideDistance / 100);
        break;
    }

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Démarrer l'animation après le délai
    Future.delayed(widget.delayDuration, () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedCard(
        onTap: widget.onTap,
        backgroundColor: widget.backgroundColor,
        child: widget.child,
      ),
    );
  }
}

enum SlideDirection { left, right, up, down }

class FadeInCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration fadeInDuration;
  final Duration delayDuration;

  const FadeInCard({
    Key? key,
    required this.child,
    this.onTap,
    this.fadeInDuration = const Duration(milliseconds: 800),
    this.delayDuration = Duration.zero,
  }) : super(key: key);

  @override
  _FadeInCardState createState() => _FadeInCardState();
}

class _FadeInCardState extends State<FadeInCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Démarrer l'animation après le délai
    Future.delayed(widget.delayDuration, () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedCard(
        onTap: widget.onTap,
        child: widget.child,
      ),
    );
  }
}

class PulseCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Duration pulseDuration;
  final double pulseScale;

  const PulseCard({
    Key? key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.pulseDuration = const Duration(milliseconds: 1500),
    this.pulseScale = 1.05,
  }) : super(key: key);

  @override
  _PulseCardState createState() => _PulseCardState();
}

class _PulseCardState extends State<PulseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.pulseDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pulseScale,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _animationController.forward();
      }
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AnimatedCard(
            onTap: widget.onTap,
            backgroundColor: widget.backgroundColor,
            child: widget.child,
          ),
        );
      },
    );
  }
}
