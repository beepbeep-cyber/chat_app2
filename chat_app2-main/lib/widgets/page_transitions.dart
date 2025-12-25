import 'package:flutter/material.dart';

/// Custom Page Transitions for Modern UI
/// Features: Slide, Fade, Scale, and combination effects

/// Slide + Fade Transition (Recommended for chat screens)
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  SlideUpRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 350),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(curve),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
                child: child,
              ),
            );
          },
        );
}

/// Slide Right Transition (For navigation flow)
class SlideRightRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  SlideRightRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 350),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0),
                end: Offset.zero,
              ).animate(curve),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.5, end: 1.0).animate(curve),
                child: child,
              ),
            );
          },
        );
}

/// Scale + Fade Transition (For modals and dialogs)
class ScaleRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  ScaleRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeInBack,
            );
            
            return ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(curve),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
                child: child,
              ),
            );
          },
        );
}

/// Shared Axis Transition (Material Design 3 style)
class SharedAxisRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final SharedAxisType type;

  SharedAxisRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 400),
    this.type = SharedAxisType.horizontal,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            
            Offset begin;
            switch (type) {
              case SharedAxisType.horizontal:
                begin = const Offset(0.3, 0);
                break;
              case SharedAxisType.vertical:
                begin = const Offset(0, 0.3);
                break;
              case SharedAxisType.scaled:
                begin = Offset.zero;
                break;
            }
            
            Widget result = FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
              child: child,
            );
            
            if (type == SharedAxisType.scaled) {
              result = ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
                child: result,
              );
            } else {
              result = SlideTransition(
                position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curve),
                child: result,
              );
            }
            
            return result;
          },
        );
}

enum SharedAxisType { horizontal, vertical, scaled }

/// Fade Through Transition (For tab switching)
class FadeThroughRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  FadeThroughRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
              ),
              child: child,
            );
          },
        );
}

/// Hero Dialog Route (For smooth dialog transitions)
class HeroDialogRoute<T> extends PageRoute<T> {
  final Widget Function(BuildContext context) builder;

  HeroDialogRoute({required this.builder});

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  bool get maintainState => true;

  @override
  Color get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve),
        child: child,
      ),
    );
  }
}

/// Navigation Helper Extension
extension NavigationExtension on BuildContext {
  /// Navigate with slide up animation
  Future<T?> pushSlideUp<T>(Widget page) {
    return Navigator.push<T>(this, SlideUpRoute<T>(page: page));
  }

  /// Navigate with slide right animation
  Future<T?> pushSlideRight<T>(Widget page) {
    return Navigator.push<T>(this, SlideRightRoute<T>(page: page));
  }

  /// Navigate with scale animation
  Future<T?> pushScale<T>(Widget page) {
    return Navigator.push<T>(this, ScaleRoute<T>(page: page));
  }

  /// Navigate with shared axis animation
  Future<T?> pushSharedAxis<T>(Widget page, {SharedAxisType type = SharedAxisType.horizontal}) {
    return Navigator.push<T>(this, SharedAxisRoute<T>(page: page, type: type));
  }

  /// Navigate with fade through animation
  Future<T?> pushFadeThrough<T>(Widget page) {
    return Navigator.push<T>(this, FadeThroughRoute<T>(page: page));
  }

  /// Replace with slide animation
  Future<T?> pushReplacementSlide<T, TO>(Widget page) {
    return Navigator.pushReplacement<T, TO>(this, SlideRightRoute<T>(page: page));
  }

  /// Pop and push with animation
  Future<T?> popAndPushSlide<T, TO>(Widget page) {
    Navigator.pop(this);
    return Navigator.push<T>(this, SlideRightRoute<T>(page: page));
  }
}

/// Staggered List Animation Helper
class StaggeredListAnimation {
  final int itemCount;
  final Duration staggerDelay;
  final Duration animationDuration;
  final List<AnimationController> controllers;
  final List<Animation<Offset>> slideAnimations;
  final List<Animation<double>> fadeAnimations;

  StaggeredListAnimation._({
    required this.itemCount,
    required this.staggerDelay,
    required this.animationDuration,
    required this.controllers,
    required this.slideAnimations,
    required this.fadeAnimations,
  });

  factory StaggeredListAnimation.create({
    required TickerProvider vsync,
    required int itemCount,
    Duration staggerDelay = const Duration(milliseconds: 50),
    Duration animationDuration = const Duration(milliseconds: 400),
  }) {
    final controllers = List<AnimationController>.generate(
      itemCount,
      (index) => AnimationController(
        duration: animationDuration,
        vsync: vsync,
      ),
    );

    final slideAnimations = controllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    final fadeAnimations = controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ));
    }).toList();

    return StaggeredListAnimation._(
      itemCount: itemCount,
      staggerDelay: staggerDelay,
      animationDuration: animationDuration,
      controllers: controllers,
      slideAnimations: slideAnimations,
      fadeAnimations: fadeAnimations,
    );
  }

  Future<void> startAnimation() async {
    for (int i = 0; i < controllers.length; i++) {
      await Future.delayed(staggerDelay);
      try {
        controllers[i].forward();
      } catch (e) {
        // Controller may have been disposed
        break;
      }
    }
  }

  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
  }

  Widget buildAnimatedItem(int index, Widget child) {
    if (index >= itemCount) return child;
    return SlideTransition(
      position: slideAnimations[index],
      child: FadeTransition(
        opacity: fadeAnimations[index],
        child: child,
      ),
    );
  }
}
