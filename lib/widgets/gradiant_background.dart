part of '../main.dart';

class GradiantBackground {
  static Widget getSafeAreaGradiant( BuildContext context,Widget child) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF98a069),
              Color(0xFF045f78),
              Color(0xFF1c2d41),
            ],
          ),
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: child,
        ),
      ),
    );
  }
}
