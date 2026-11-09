import 'shared/campus_access_layout.dart';
import 'shared/password_recovery_dialog.dart';
import '../core/app_colors.dart';

import 'package:flutter/material.dart';

import '../config/academic_catalog.dart';

import '../services/campus_auth_service.dart';
import '../services/instructor_registration_service.dart';
import '../services/password_reset_service.dart';

enum RegistrationAccountType { student, instructor }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.authService,
    this.instructorRegistrationService,
    this.passwordResetService,
    this.initialSignUp = false,
  });
  final CampusAuthService? authService;
  final InstructorRegistrationService? instructorRegistrationService;
  final PasswordResetService? passwordResetService;
  final bool initialSignUp;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Color red = AppColors.error;

  static const Color green = AppColors.green;

  late final CampusAuthService _authService =
      widget.authService ?? CampusAuthService();

  late final InstructorRegistrationService _instructorRegistrationService =
      widget.instructorRegistrationService ?? InstructorRegistrationService();

  late final PasswordResetService _passwordResetService =
      widget.passwordResetService ?? PasswordResetService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _campusIdController = TextEditingController();

  final TextEditingController _departmentController = TextEditingController(
    text: AcademicCatalog.department,
  );

  final TextEditingController _courseController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  late bool _isSignUpMode = widget.initialSignUp;
  bool _isLoading = false;
  bool _isPickingFile = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  RegistrationAccountType _registrationAccountType =
      RegistrationAccountType.student;

  FacultyIdDocument? _facultyIdDocument;
  bool get _busy => _isLoading || _isPickingFile;

  bool get _isInstructorRegistration =>
      _isSignUpMode &&
      _registrationAccountType == RegistrationAccountType.instructor;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _campusIdController.dispose();
    _departmentController.dispose();
    _courseController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _switchMode(bool signUp) {
    if (_busy || signUp == _isSignUpMode) {
      return;
    }

    FocusScope.of(context).unfocus();
    _formKey.currentState?.reset();

    setState(() {
      _isSignUpMode = signUp;
      _showPassword = false;
      _showConfirmPassword = false;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  void _selectAccountType(RegistrationAccountType type) {
    if (_busy || type == _registrationAccountType) {
      return;
    }

    FocusScope.of(context).unfocus();
    _formKey.currentState?.reset();

    setState(() {
      _registrationAccountType = type;
      _facultyIdDocument = null;
      _departmentController.text = AcademicCatalog.department;
      _courseController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _showPassword = false;
      _showConfirmPassword = false;
    });
  }

  Future<void> _pickFacultyId() async {
    if (_isLoading || _isPickingFile) {
      return;
    }

    setState(() {
      _isPickingFile = true;
    });

    try {
      final FacultyIdDocument? document = await _instructorRegistrationService
          .pickFacultyIdDocument();

      if (!mounted || document == null) {
        return;
      }

      setState(() {
        _facultyIdDocument = document;
      });
    } on CampusAuthException catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('Unable to select the faculty ID file.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_busy) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signIn(
        campusId: _campusIdController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on CampusAuthException catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('Unable to log in. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignUp() async {
    if (_busy) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match.');

      return;
    }

    if (_isInstructorRegistration && _facultyIdDocument == null) {
      _showError('Please upload your faculty ID.');

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isInstructorRegistration) {
        await _instructorRegistrationService.registerInstructor(
          fullName: _fullNameController.text,
          email: _emailController.text,
          campusId: _campusIdController.text,
          department: _departmentController.text,
          position: _courseController.text,
          password: _passwordController.text,
          facultyId: _facultyIdDocument!,
        );
      } else {
        await _authService.signUpStudent(
          fullName: _fullNameController.text,
          email: _emailController.text,
          campusId: _campusIdController.text,
          department: _departmentController.text,
          course: _courseController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on CampusAuthException catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError(
          _isInstructorRegistration
              ? 'Unable to submit the instructor application.'
              : 'Unable to create your account.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_isSignUpMode) {
      await _handleSignUp();
    } else {
      await _handleLogin();
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PasswordRecoveryDialog(
        authService: _authService,
        resetService: _passwordResetService,
        initialCampusId: _campusIdController.text.trim(),
      ),
    );
    if (mounted && sent == true) {
      _showSuccess(
        'If the information matches an account, a password reset link has been sent to the registered Gmail address.',
      );
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return CampusAccessLayout(
      signUp: _isSignUpMode,
      busy: _busy,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isSignUpMode ? 'Join your CAS community' : 'Welcome back',
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isSignUpMode
                    ? 'Create an account to start learning together.'
                    : 'Sign in with your student or faculty ID.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 24),
              Container(
                key: const ValueKey('auth-controls-card'),
                padding: mobile ? const EdgeInsets.all(18) : EdgeInsets.zero,
                decoration: mobile
                    ? BoxDecoration(
                        color: colors.surface,
                        border: Border.all(color: colors.outlineVariant),
                        borderRadius: BorderRadius.circular(22),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _choices([
                      _choice(
                        'Sign in',
                        !_isSignUpMode,
                        () => _switchMode(false),
                      ),
                      _choice(
                        'Create account',
                        _isSignUpMode,
                        () => _switchMode(true),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    if (_isSignUpMode) ...[
                      Text(
                        'I am a',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _choices([
                        _choice(
                          'Student',
                          !_isInstructorRegistration,
                          () => _selectAccountType(
                            RegistrationAccountType.student,
                          ),
                          icon: Icons.school_outlined,
                        ),
                        _choice(
                          'Instructor',
                          _isInstructorRegistration,
                          () => _selectAccountType(
                            RegistrationAccountType.instructor,
                          ),
                          icon: Icons.person_outline_rounded,
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _field(
                        'auth-full-name',
                        _fullNameController,
                        'Full name',
                        Icons.person_outline_rounded,
                        hints: const [AutofillHints.name],
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Enter your full name.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _field(
                        'auth-email',
                        _emailController,
                        'Gmail address',
                        Icons.mail_outline_rounded,
                        hints: const [AutofillHints.email],
                        keyboard: TextInputType.emailAddress,
                        validator: (v) =>
                            !_authService.isValidEmail((v ?? '').trim())
                            ? 'Enter a valid Gmail address.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _field(
                      'auth-id',
                      _campusIdController,
                      _isSignUpMode
                          ? (_isInstructorRegistration
                                ? 'Faculty ID number'
                                : 'Student ID number')
                          : 'Student or faculty ID',
                      Icons.badge_outlined,
                      hints: const [AutofillHints.username],
                      keyboard: TextInputType.number,
                      validator: (v) =>
                          !_authService.isValidCampusId((v ?? '').trim())
                          ? 'Enter a valid ID number.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    if (_isSignUpMode) ...[
                      Text(
                        AcademicCatalog.department,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_isInstructorRegistration)
                        _field(
                          'auth-position',
                          _courseController,
                          'Position / designation',
                          Icons.work_outline_rounded,
                          validator: (v) => (v ?? '').trim().length < 2
                              ? 'Enter your position.'
                              : null,
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'auth-program-$_registrationAccountType',
                          ),
                          initialValue: _courseController.text.isEmpty
                              ? null
                              : _courseController.text,
                          isExpanded: true,
                          decoration: _decoration(
                            'Degree program',
                            Icons.school_outlined,
                          ),
                          items: AcademicCatalog
                              .programs[AcademicCatalog.department]!
                              .map(
                                (code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(
                                    AcademicCatalog.programLabel(code),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) => _courseController.text = value ?? '',
                          validator: (value) => value == null
                              ? 'Select your degree program.'
                              : null,
                        ),
                      const SizedBox(height: 16),
                      if (_isInstructorRegistration) ...[
                        OutlinedButton.icon(
                          key: const ValueKey('auth-faculty-id'),
                          style: OutlinedButton.styleFrom(
                            textStyle: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _busy ? null : _pickFacultyId,
                          icon: Icon(
                            _facultyIdDocument == null
                                ? Icons.upload_file_rounded
                                : Icons.check_circle_outline_rounded,
                          ),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _isPickingFile
                                  ? 'Selecting file…'
                                  : _facultyIdDocument?.name ??
                                        'Attach faculty ID',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Required for approval · JPG, PNG, WebP or PDF · up to 5 MB',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    TextFormField(
                      key: const ValueKey('auth-password'),
                      controller: _passwordController,
                      enabled: !_busy,
                      obscureText: !_showPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: [
                        _isSignUpMode
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: _isSignUpMode
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: _isSignUpMode ? null : (_) => _submit(),
                      decoration:
                          _decoration(
                            'Password',
                            Icons.lock_outline_rounded,
                          ).copyWith(
                            helperText: _isSignUpMode
                                ? 'At least 6 characters'
                                : null,
                            suffixIcon: IconButton(
                              tooltip: _showPassword
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _showPassword = !_showPassword,
                                    ),
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                      validator: (v) => (v ?? '').isEmpty
                          ? 'Enter your password.'
                          : _isSignUpMode && v!.length < 6
                          ? 'Use at least 6 characters.'
                          : null,
                    ),
                    if (_isSignUpMode) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('auth-confirm-password'),
                        controller: _confirmPasswordController,
                        enabled: !_busy,
                        obscureText: !_showConfirmPassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration:
                            _decoration(
                              'Confirm password',
                              Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                tooltip: _showConfirmPassword
                                    ? 'Hide confirmation'
                                    : 'Show confirmation',
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _showConfirmPassword =
                                            !_showConfirmPassword,
                                      ),
                                icon: Icon(
                                  _showConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                        validator: (v) => (v ?? '').isEmpty
                            ? 'Confirm your password.'
                            : v != _passwordController.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _isInstructorRegistration
                                ? Icons.verified_user_outlined
                                : Icons.mark_email_read_outlined,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isInstructorRegistration
                                  ? 'Your faculty ID will be reviewed by an administrator before you can access instructor features.'
                                  : 'Verify your Gmail address after registration to access your account.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _showForgotPasswordDialog,
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(fontFamily: 'Roboto'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const ValueKey('auth-submit'),
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        textStyle: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isSignUpMode
                                  ? (_isInstructorRegistration
                                        ? 'Submit for approval'
                                        : 'Create account')
                                  : 'Sign in',
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String key,
    TextEditingController controller,
    String label,
    IconData icon, {
    required FormFieldValidator<String> validator,
    List<String>? hints,
    TextInputType? keyboard,
  }) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    enabled: !_busy,
    validator: validator,
    autofillHints: hints,
    keyboardType: keyboard,
    autocorrect: false,
    textInputAction: TextInputAction.next,
    decoration: _decoration(label, icon),
  );

  Widget _choices(List<Widget> children) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: .5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(children: children),
  );

  Widget _choice(
    String label,
    bool selected,
    VoidCallback onPressed, {
    IconData? icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: TextButton(
        onPressed: _busy ? null : onPressed,
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: selected
              ? colors.primaryContainer
              : Colors.transparent,
          foregroundColor: selected
              ? colors.onPrimaryContainer
              : colors.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Semantics(
          selected: selected,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 7),
              ],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    );
  }
}
