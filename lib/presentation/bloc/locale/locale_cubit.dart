import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

/// Locale Cubit for switching between English (LTR) and Arabic (RTL).
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('en'));

  /// Switches to English.
  void setEnglish() => emit(const Locale('en'));

  /// Switches to Arabic.
  void setArabic() => emit(const Locale('ar'));

  /// Toggles between English and Arabic.
  void toggle() {
    if (state.languageCode == 'ar') {
      emit(const Locale('en'));
    } else {
      emit(const Locale('ar'));
    }
  }

  /// Whether current locale is RTL.
  bool get isRtl => state.languageCode == 'ar';
}
