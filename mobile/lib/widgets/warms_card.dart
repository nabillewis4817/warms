import 'package:flutter/material.dart';
import '../themes/warms_theme.dart';

/// Carte WARMS - Cohérente avec l'application web
/// 
/// Ce widget implémente le style de carte de l'application web WARMS
/// avec les mêmes animations, ombres et effets de survol.
/// 
/// @author WARMS Team
/// @version 2.0.0
class WarmsCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool animated;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final bool showFloatingBubble;
  final bool showSpinningDiamond;

  const WarmsCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
    this.animated = true,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.showFloatingBubble = false,
    this.showSpinningDiamond = false,
  });

  @override
  State<WarmsCard> createState() => _WarmsCardState();
}

class _WarmsCardState extends State<WarmsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.animated) {
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 250),
        vsync: this,
      );
      
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: 1.02,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
      
      _elevationAnimation = Tween<double>(
        begin: widget.elevation ?? 10.0,
        end: (widget.elevation ?? 10.0) + 6.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
    }
  }

  @override
  void dispose() {
    if (widget.animated) {
      _animationController.dispose();
    }
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.animated) {
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.animated) {
      _animationController.reverse();
    }
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (widget.animated) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      child: AnimatedBuilder(
        animation: widget.animated ? _animationController : const AlwaysStoppedAnimation(0),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.animated ? _scaleAnimation.value : 1.0,
            child: Container(
              margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                children: [
                  // Carte principale
                  Material(
                    elevation: widget.animated ? _elevationAnimation.value : (widget.elevation ?? 10.0),
                    shadowColor: isDark 
                        ? Colors.black.withValues(alpha: 0.3)
                        : WarmsTheme.warmsBlue.withValues(alpha: 0.15),
                    borderRadius: widget.borderRadius ?? BorderRadius.circular(18),
                    color: widget.backgroundColor ?? 
                        (isDark ? WarmsTheme.warmsDarkCard : WarmsTheme.warmsCard),
                    child: Container(
                      padding: widget.padding ?? const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: widget.borderRadius ?? BorderRadius.circular(18),
                        gradient: isDark ? null : WarmsTheme.warmsCardGradient,
                        border: isDark 
                            ? Border.all(color: WarmsTheme.warmsNavy.withValues(alpha: 0.2))
                            : null,
                      ),
                      child: widget.child,
                    ),
                  ),
                  
                  // Bulle flottante (comme dans l'app web)
                  if (widget.showFloatingBubble)
                    Positioned(
                      right: -30,
                      top: 20,
                      child: _FloatingBubble(),
                    ),
                  
                  // Diamant rotatif (comme dans l'app web)
                  if (widget.showSpinningDiamond)
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: _SpinningDiamond(),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bulle flottante animée - Inspirée de l'application web
class _FloatingBubble extends StatefulWidget {
  @override
  __FloatingBubbleState createState() => __FloatingBubbleState();
}

class __FloatingBubbleState extends State<_FloatingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    _floatAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final floatY = -16.0 * _floatAnimation.value;
        final scale = _scaleAnimation.value;
        
        return Transform.translate(
          offset: Offset(0, floatY),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    WarmsTheme.warmsAccent.withValues(alpha: 0.22),
                    WarmsTheme.warmsAccent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Diamant rotatif animé - Inspiré de l'application web
class _SpinningDiamond extends StatefulWidget {
  @override
  __SpinningDiamondState createState() => __SpinningDiamondState();
}

class __SpinningDiamondState extends State<_SpinningDiamond>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 16),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
    
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value * 2 * 3.14159,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: WarmsTheme.warmsBlue.withValues(alpha: 0.1),
            ),
            child: Transform.rotate(
              angle: 45 * 3.14159 / 180,
              child: Container(
                width: 30,
                height: 30,
                color: Colors.transparent,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bouton WARMS - Cohérent avec l'application web
class WarmsButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final WarmsButtonType type;
  final bool isLoading;
  final Size? size;

  const WarmsButton({
    super.key,
    required this.child,
    this.onPressed,
    this.type = WarmsButtonType.primary,
    this.isLoading = false,
    this.size,
  });

  @override
  State<WarmsButton> createState() => _WarmsButtonState();
}

enum WarmsButtonType {
  primary,
  secondary,
  success,
  warning,
  error,
  info,
}

class _WarmsButtonState extends State<WarmsButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
      widget.onPressed!();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case WarmsButtonType.primary:
        return WarmsTheme.warmsAccent;
      case WarmsButtonType.secondary:
        return WarmsTheme.warmsBlue;
      case WarmsButtonType.success:
        return WarmsTheme.warmsSuccess;
      case WarmsButtonType.warning:
        return WarmsTheme.warmsWarning;
      case WarmsButtonType.error:
        return WarmsTheme.warmsError;
      case WarmsButtonType.info:
        return WarmsTheme.warmsInfo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                width: widget.size?.width,
                height: widget.size?.height ?? 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getBackgroundColor(),
                      _getBackgroundColor().withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _getBackgroundColor().withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.isLoading ? null : widget.onPressed,
                    child: Center(
                      child: widget.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : widget.child,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
