import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Theme Cubit for switching between light and dark (OLED) modes.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  /// Switches to light mode.
  void setLightMode() => emit(ThemeMode.light);

  /// Switches to dark (True Black OLED) mode.
  void setDarkMode() => emit(ThemeMode.dark);

  /// Follows the system theme.
  void setSystemMode() => emit(ThemeMode.system);

  /// Toggles between light and dark mode.
  void toggle() {
    if (state == ThemeMode.dark) {
      emit(ThemeMode.light);
    } else {
      emit(ThemeMode.dark);
    }
  }
}
