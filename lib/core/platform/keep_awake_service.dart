abstract interface class KeepAwakeService {
  bool get isSupported;
  Future<void> enable();
  Future<void> disable();
}

class UnsupportedKeepAwakeService implements KeepAwakeService {
  const UnsupportedKeepAwakeService();
  @override
  bool get isSupported => false;
  @override
  Future<void> enable() async {}
  @override
  Future<void> disable() async {}
}
