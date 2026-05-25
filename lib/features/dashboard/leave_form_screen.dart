import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/models/leave_type.dart';

class LeaveFormScreen extends StatefulWidget {
  const LeaveFormScreen({super.key});

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final _formKey = GlobalKey<FormState>();

  LeaveType? selectedLeaveType;
  DateTime? startDate;
  DateTime? endDate;
  final TextEditingController _reasonController = TextEditingController();

  int get totalDays {
    if (startDate == null || endDate == null) return 0;
    return LeaveRequest.calculateTotalLeave(startDate!, endDate!);
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = null;
          }
        } else {
          endDate = picked;
        }
      });
    }
  }

  void _submitLeave() {
    if (_formKey.currentState?.validate() ?? false) {
      if (selectedLeaveType == null || startDate == null || endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields')),
        );
        return;
      }

      final leave = LeaveRequest(
        id: null,
        dateStart: startDate!,
        dateEnd: endDate!,
        leaveType: selectedLeaveType!,
        employeeID: 101, // TODO: Replace with real user ID from auth provider
        totalLeave: totalDays,
        approveBy: "",
      );

      developer.log('Leave Request Submitted: ${leave.toJson()}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form after successful submission
      _resetForm();
    }
  }

  void _resetForm() {
    setState(() {
      selectedLeaveType = null;
      startDate = null;
      endDate = null;
      _reasonController.clear();
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Leave'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Leave Request',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Fill in the details below',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Leave Type
              DropdownButtonFormField<LeaveType>(
                value: selectedLeaveType,
                hint: const Text('Select Leave Type'),
                decoration: InputDecoration(
                  labelText: 'Leave Type *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: LeaveType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayLabel),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedLeaveType = value),
                validator: (value) => value == null ? 'Please select a leave type' : null,
              ),

              const SizedBox(height: 20),

              // Date Range
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'Start Date *',
                      selectedDate: startDate,
                      onTap: () => _selectDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateField(
                      label: 'End Date *',
                      selectedDate: endDate,
                      onTap: () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Total Days
              if (totalDays > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(30), // Fixed deprecation
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        '$totalDays day${totalDays > 1 ? 's' : ''}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text('Total Duration', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Reason
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Reason for Leave',
                  hintText: 'Explain why you need this leave...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _submitLeave,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(
                    'Submit Leave Request',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          selectedDate != null
              ? "${selectedDate.day.toString().padLeft(2, '0')}/"
                  "${selectedDate.month.toString().padLeft(2, '0')}/"
                  "${selectedDate.year}"
              : 'Select date',
        ),
      ),
    );
  }
}