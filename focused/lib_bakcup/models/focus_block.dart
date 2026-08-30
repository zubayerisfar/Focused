enum FocusBlockType { focus, breakTime }

class FocusBlock {
  final FocusBlockType type;
  final Duration duration;

  const FocusBlock({required this.type, required this.duration});

  bool get isFocus {
    return type == FocusBlockType.focus;
  }

  bool get isBreak {
    return type == FocusBlockType.breakTime;
  }
}
