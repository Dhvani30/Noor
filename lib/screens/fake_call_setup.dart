import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/fake_call.dart';
import '../services/fake_call_service.dart';

class FakeCallSetup extends StatefulWidget {
  const FakeCallSetup({super.key});

  @override
  State<FakeCallSetup> createState() => _FakeCallSetupState();
}

class _FakeCallSetupState extends State<FakeCallSetup> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Name');
  final _phoneController = TextEditingController(text: '+91 9123456789');

  DateTime _selectedTime = DateTime.now().add(const Duration(minutes: 2));
  bool _isImmediate = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (await Permission.scheduleExactAlarm.isDenied) {
      final granted = await Permission.scheduleExactAlarm.request();
      if (!granted.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Exact alarm permission denied. Scheduled calls may not work when phone is locked.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);

    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Colors.green),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = DateTime.now().copyWith(
          hour: picked.hour,
          minute: picked.minute,
          second: 0,
          millisecond: 0,
        );
        if (_selectedTime.isBefore(DateTime.now())) {
          _selectedTime = _selectedTime.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _triggerCall() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final call = _isImmediate
          ? FakeCall.immediate(
              name: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
            )
          : FakeCall.scheduled(
              name: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              scheduledTime: _selectedTime,
            );

      if (_isImmediate) {
        await FakeCallService().triggerImmediateCall(context, call);
      } else {
        await FakeCallService().scheduleCall(call, context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('📞 Fake Call'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Uses your device\'s actual ringtone & vibration',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Caller Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'When should the call ring?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),

                            RadioListTile<bool>(
                              title: const Text('🔔 Call Now'),
                              subtitle: const Text('Ring immediately'),
                              value: true,
                              groupValue: _isImmediate,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _isImmediate = value);
                                }
                              },
                              activeColor: Colors.green,
                            ),

                            RadioListTile<bool>(
                              title: const Text('⏰ Schedule for Later'),
                              subtitle: Text(
                                'Ring at ${_formatTime(_selectedTime)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              value: false,
                              groupValue: _isImmediate,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _isImmediate = value);
                                }
                              },
                              activeColor: Colors.green,
                            ),

                            if (!_isImmediate) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _pickTime,
                                icon: const Icon(Icons.access_time),
                                label: const Text('Change Time'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _triggerCall,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.phone_callback, size: 24),
                      label: Text(
                        _isImmediate ? '🔔 Call Now' : '⏰ Schedule Call',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isImmediate
                            ? Colors.green
                            : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a • EEE, MMM d').format(time);
  }
}
