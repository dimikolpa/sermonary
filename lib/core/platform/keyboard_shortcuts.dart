import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

SingleActivator primaryShortcut(
  LogicalKeyboardKey key, {
  bool alt = false,
  bool shift = false,
}) => SingleActivator(
  key,
  control: !Platform.isMacOS,
  meta: Platform.isMacOS,
  alt: alt,
  shift: shift,
);

String get primaryShortcutModifier => Platform.isMacOS ? '⌘' : 'Ctrl+';

bool get isPrimaryShortcutPressed => Platform.isMacOS
    ? HardwareKeyboard.instance.isMetaPressed
    : HardwareKeyboard.instance.isControlPressed;
