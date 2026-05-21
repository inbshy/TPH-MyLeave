import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/models/leave_type.dart';

class LeaveFormScreen extends StatefulWidget {
  const LeaveFormScreen({super.key});
  @override
  State<LeaveFormScreen> createState() => LeaveFormScreenState();
}

class LeaveFormScreenState extends State<LeaveFormScreen> {
  LeaveType? selectedLeaveType;
  DateTime? startDate;
  DateTime? endDate;

  void submitLeave() {
    final leave = LeaveRequest(
      id: 1,
      dateStart: startDate!,
      dateEnd: endDate!,
      leaveType: selectedLeaveType!,
      employeeID: 101,
      totalLeave: LeaveRequest.calculateTotalLeave(startDate!, endDate!),
      approveBy: "",
    );

    developer.log(leave.toJson().toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Apply Leave")),
      body: Column(
        children: [
          DropdownButtonFormField<LeaveType>(
            hint: Text("Select Leave Type"),
            items: LeaveType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.displayLabel),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedLeaveType = value!;
              });
            },
          ),
          ElevatedButton(
            onPressed: submitLeave,
            child: Text("Submit"),
          )
        ],
      ),
    );
  }
}

