import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/services/employee_service.dart';

final employeeServiceProvider =
    Provider<EmployeeService>((ref) => EmployeeService());
