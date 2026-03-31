class FakeCall {
  final String name;
  final String phoneNumber;
  final DateTime? scheduledTime;
  final bool isImmediate;

  FakeCall({
    required this.name,
    required this.phoneNumber,
    this.scheduledTime,
    this.isImmediate = false,
  });

  factory FakeCall.immediate({
    required String name,
    required String phoneNumber,
  }) {
    return FakeCall(name: name, phoneNumber: phoneNumber, isImmediate: true);
  }

  factory FakeCall.scheduled({
    required String name,
    required String phoneNumber,
    required DateTime scheduledTime,
  }) {
    return FakeCall(
      name: name,
      phoneNumber: phoneNumber,
      scheduledTime: scheduledTime,
      isImmediate: false,
    );
  }
}
