import 'package:form_field_validator/form_field_validator.dart';

class AppValidators {
  AppValidators._();

  static final email = MultiValidator([
    RequiredValidator(errorText: 'Email is required'),
    EmailValidator(errorText: 'Enter a valid email'),
  ]);

  static final password = MultiValidator([
    RequiredValidator(errorText: 'Password is required'),
    MinLengthValidator(6, errorText: 'At least 6 characters'),
  ]);
}
