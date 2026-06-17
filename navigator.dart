import '../../exports.dart';

extension NavigationExtension on BuildContext {
  void navigateWithTransition(Widget page, TransitionType transitionType,
      {bool replace = false}) {
    final route = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return page;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = _getTween(transitionType);
        final offsetAnimation = animation.drive(tween);
        final fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(animation);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );

    if (replace) {
      Navigator.of(this).pushReplacement(route);
    } else {
      Navigator.of(this).push(route);
    }
  }

  void navigateBackWithFadeAnimation() {
    Navigator.of(this).pop();
  }

  Tween<Offset> _getTween(TransitionType transitionType) {
    switch (transitionType) {
      case TransitionType.leftToRight:
        return Tween(begin: const Offset(-1.0, 0.0), end: Offset.zero);
      case TransitionType.rightToLeft:
        return Tween(begin: const Offset(1.0, 0.0), end: Offset.zero);
      case TransitionType.bottomToTop:
        return Tween(begin: const Offset(0.0, 1.0), end: Offset.zero);
      case TransitionType.topToBottom:
        return Tween(begin: const Offset(0.0, -1.0), end: Offset.zero);
      case TransitionType.fade:
      default:
        return Tween(begin: Offset.zero, end: Offset.zero);
    }
  }
}

enum TransitionType {
  fade,
  leftToRight,
  rightToLeft,
  bottomToTop,
  topToBottom,
}
