
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'keyboard_done_button_ios_platform_interface.dart';

/// Utility class for controlling the keyboard Done button toolbar.
class KeyboardToolbar {
  /// Shows the Done button toolbar above the keyboard.
  static Future<void> show() async {
    if (Platform.isIOS) {
      await KeyboardDoneButtonIosPlatform.instance.showDoneButton();
    }
  }

  /// Hides the Done button toolbar.
  static Future<void> hide() async {
    if (Platform.isIOS) {
      await KeyboardDoneButtonIosPlatform.instance.hideDoneButton();
    }
  }
}

/// A widget that automatically shows or hides the keyboard Done button
/// toolbar based on the focus state of its child.
///
/// If a [FocusNode] is provided, the widget observes that node without
/// attaching it to another [Focus] widget.
///
/// If no [FocusNode] is provided, the widget creates and manages its
/// own [FocusNode].
class KeyboardToolbarField extends StatefulWidget {
  /// The child widget, typically a TextField or TextFormField.
  final Widget child;

  /// Whether to show the toolbar when the field is focused.
  ///
  /// Defaults to true.
  final bool showToolbar;

  /// Optional FocusNode.
  ///
  /// If not provided, a FocusNode will be created internally.
  final FocusNode? focusNode;

  const KeyboardToolbarField({
    super.key,
    required this.child,
    this.showToolbar = true,
    this.focusNode,
  });

  @override
  State<KeyboardToolbarField> createState() =>
      _KeyboardToolbarFieldState();
}

class _KeyboardToolbarFieldState extends State<KeyboardToolbarField> {
  late FocusNode _focusNode;
  bool _ownsNode = false;

  @override
  void initState() {
    super.initState();
    _initFocusNode();

    // Handle the case where the field is already focused.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateToolbar();
      }
    });
  }

  /// Initializes the FocusNode and registers its listener.
  void _initFocusNode() {
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _ownsNode = false;
    } else {
      _focusNode = FocusNode();
      _ownsNode = true;
    }

    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant KeyboardToolbarField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle FocusNode changes.
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);

      if (_ownsNode) {
        _focusNode.dispose();
      }

      _initFocusNode();
    }

    // Handle showToolbar changes while the field is focused.
    if (widget.showToolbar != oldWidget.showToolbar &&
        _focusNode.hasFocus) {
      _updateToolbar();
    }
  }

  /// Called whenever the FocusNode changes.
  void _onFocusChange() {
    debugPrint('[KeyboardToolbarField] Focus changed');
    _updateToolbar();
  }

  /// Updates native toolbar visibility based on the current focus state.
  void _updateToolbar() {
    debugPrint(
      '[KeyboardToolbarField] '
          'hasFocus: ${_focusNode.hasFocus}, '
          'showToolbar: ${widget.showToolbar}',
    );

    if (_focusNode.hasFocus && widget.showToolbar) {
      debugPrint('[KeyboardToolbarField] Requesting SHOW');
      KeyboardToolbar.show();
    } else {
      debugPrint('[KeyboardToolbarField] Requesting HIDE');
      KeyboardToolbar.hide();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);

    // Only dispose FocusNodes created by this widget.
    if (_ownsNode) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When an external FocusNode is supplied, the child (TextField or
    // TextFormField) already attaches that node to the focus tree.
    // Do not attach the same node to another Focus widget.
    if (widget.focusNode != null) {
      return widget.child;
    }

    // When no external FocusNode is supplied, use our internally
    // managed FocusNode to observe focus changes.
    return Focus(
      focusNode: _focusNode,
      child: widget.child,
    );
  }
}
