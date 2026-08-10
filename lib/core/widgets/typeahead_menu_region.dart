import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef TypeaheadMenuBuilder =
    Widget Function(BuildContext context, TypeaheadMenuController controller);

class TypeaheadMenuController {
  TypeaheadMenuController._(this._open, this._close);

  final VoidCallback _open;
  final VoidCallback _close;

  void open() => _open();

  void close() => _close();
}

class TypeaheadMenuRegion<T> extends StatefulWidget {
  const TypeaheadMenuRegion({
    required this.options,
    required this.labelFor,
    required this.onSelected,
    required this.builder,
    this.resetDelay = const Duration(milliseconds: 900),
    super.key,
  });

  final List<T> options;
  final String Function(T option) labelFor;
  final ValueChanged<T> onSelected;
  final TypeaheadMenuBuilder builder;
  final Duration resetDelay;

  @override
  State<TypeaheadMenuRegion<T>> createState() => _TypeaheadMenuRegionState<T>();
}

class _TypeaheadMenuSession {
  static VoidCallback? _cancelActive;

  static void activate(VoidCallback cancel) {
    if (_cancelActive != cancel) _cancelActive?.call();
    _cancelActive = cancel;
  }

  static void clear(VoidCallback cancel) {
    if (_cancelActive == cancel) _cancelActive = null;
  }
}

class _TypeaheadMenuRegionState<T> extends State<TypeaheadMenuRegion<T>> {
  late final TypeaheadMenuController _controller = TypeaheadMenuController._(
    _open,
    _close,
  );
  Timer? _resetTimer;
  var _buffer = '';
  var _active = false;
  var _menuOpen = false;
  var _keepActiveAfterDismiss = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    _deactivate();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  void _open() {
    _deactivate();
    _active = true;
    _menuOpen = true;
    _TypeaheadMenuSession.activate(_deactivate);
  }

  void _close() {
    _menuOpen = false;
    if (_keepActiveAfterDismiss) {
      _keepActiveAfterDismiss = false;
      return;
    }
    _deactivate();
  }

  void _deactivate() {
    _resetTimer?.cancel();
    _resetTimer = null;
    _buffer = '';
    _active = false;
    _menuOpen = false;
    _keepActiveAfterDismiss = false;
    _TypeaheadMenuSession.clear(_deactivate);
  }

  void _scheduleReset() {
    _resetTimer?.cancel();
    _resetTimer = Timer(widget.resetDelay, _deactivate);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!_active || event is! KeyDownEvent) return false;
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null) {
      _deactivate();
      return false;
    }
    if (HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_buffer.isNotEmpty) {
        _buffer = _buffer.substring(0, _buffer.length - 1);
        _selectMatch();
        _scheduleReset();
      }
      return true;
    }
    final eventCharacter = event.character;
    final character = eventCharacter?.isNotEmpty == true
        ? eventCharacter!
        : event.logicalKey.keyLabel;
    if (!RegExp(r'^[A-Za-z0-9ÄÖÜäöüß]$').hasMatch(character)) return false;
    final normalized = _normalizeTypeaheadText(character);
    if (normalized.isEmpty) return false;
    _buffer += normalized;
    _selectMatch();
    _scheduleReset();
    return true;
  }

  void _selectMatch() {
    if (_buffer.isEmpty) return;
    final match = widget.options
        .where(
          (option) =>
              _normalizeTypeaheadText(widget.labelFor(option)).startsWith(
                _buffer,
              ),
        )
        .firstOrNull;
    if (match == null) return;
    final dismissMenu = _menuOpen;
    if (dismissMenu) {
      _menuOpen = false;
      _keepActiveAfterDismiss = true;
    }
    widget.onSelected(match);
    if (!dismissMenu) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(Navigator.of(context).maybePop());
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

String _normalizeTypeaheadText(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp('[^a-z0-9]'), '');
