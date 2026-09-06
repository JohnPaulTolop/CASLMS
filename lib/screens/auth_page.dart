import 'package:flutter/material.dart';

import '../services/campus_auth_service.dart';
import '../services/instructor_registration_service.dart';

enum RegistrationAccountType {
  student,
  instructor,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
  });

  @override
  State<AuthScreen> createState() =>
      _AuthScreenState();
}

class _AuthScreenState
    extends State<AuthScreen> {
  static const Color primaryBlue =
      Color(0xFF1769FF);

  static const Color darkText =
      Color(0xFF10182F);

  static const Color greyText =
      Color(0xFF68738A);

  static const Color background =
      Color(0xFFF8FAFD);

  static const Color borderColor =
      Color(0xFFE3E7EE);

  static const Color red =
      Color(0xFFFF4B4B);

  static const Color green =
      Color(0xFF26A65B);

  static const Color lightBlue =
      Color(0xFFEAF3FF);

  final CampusAuthService _authService =
      CampusAuthService();

  final InstructorRegistrationService
      _instructorRegistrationService =
      InstructorRegistrationService();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController
      _fullNameController =
      TextEditingController();

  final TextEditingController
      _emailController =
      TextEditingController();

  final TextEditingController
      _campusIdController =
      TextEditingController();

  final TextEditingController
      _departmentController =
      TextEditingController();

  final TextEditingController
      _courseController =
      TextEditingController();

  final TextEditingController
      _passwordController =
      TextEditingController();

  final TextEditingController
      _confirmPasswordController =
      TextEditingController();

  bool _isSignUpMode = false;
  bool _isLoading = false;
  bool _isPickingFile = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  RegistrationAccountType
      _registrationAccountType =
      RegistrationAccountType.student;

  FacultyIdDocument? _facultyIdDocument;

  bool get _isInstructorRegistration =>
      _isSignUpMode &&
      _registrationAccountType ==
          RegistrationAccountType.instructor;

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

  void _switchMode(
    bool signUp,
  ) {
    if (_isLoading ||
        signUp == _isSignUpMode) {
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

  void _selectAccountType(
    RegistrationAccountType type,
  ) {
    if (_isLoading ||
        type == _registrationAccountType) {
      return;
    }

    FocusScope.of(context).unfocus();
    _formKey.currentState?.reset();

    setState(() {
      _registrationAccountType = type;
      _facultyIdDocument = null;
      _courseController.clear();
    });
  }

  Future<void> _pickFacultyId() async {
    if (_isLoading ||
        _isPickingFile) {
      return;
    }

    setState(() {
      _isPickingFile = true;
    });

    try {
      final FacultyIdDocument? document =
          await _instructorRegistrationService
              .pickFacultyIdDocument();

      if (!mounted ||
          document == null) {
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
        _showError(
          'Unable to select the faculty ID file.',
        );
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
    if (_isLoading) {
      return;
    }

    if (!(_formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signIn(
        campusId:
            _campusIdController.text,
        password:
            _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } on CampusAuthException catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError(
          'Unable to log in. Please try again.',
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

  Future<void> _handleSignUp() async {
    if (_isLoading) {
      return;
    }

    if (!(_formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    if (_passwordController.text !=
        _confirmPasswordController.text) {
      _showError(
        'Passwords do not match.',
      );

      return;
    }

    if (_isInstructorRegistration &&
        _facultyIdDocument == null) {
      _showError(
        'Please upload your faculty ID.',
      );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isInstructorRegistration) {
        await _instructorRegistrationService
            .registerInstructor(
          fullName:
              _fullNameController.text,
          email:
              _emailController.text,
          campusId:
              _campusIdController.text,
          department:
              _departmentController.text,
          position:
              _courseController.text,
          password:
              _passwordController.text,
          facultyId:
              _facultyIdDocument!,
        );
      } else {
        await _authService.signUpStudent(
          fullName:
              _fullNameController.text,
          email:
              _emailController.text,
          campusId:
              _campusIdController.text,
          department:
              _departmentController.text,
          course:
              _courseController.text,
          password:
              _passwordController.text,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
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

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: darkText,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 520,
            ),
            child: SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                24,
                10,
                24,
                40,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration:
                            BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(
                            22,
                          ),
                          border: Border.all(
                            color: borderColor,
                          ),
                          image:
                              const DecorationImage(
                            image: AssetImage(
                              'assets/images/CASlogo.jpg',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Text(
                      _isSignUpMode
                          ? 'Create your account'
                          : 'Welcome back',
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        color: darkText,
                        fontSize: 27,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(
                      height: 7,
                    ),
                    Text(
                      _isSignUpMode
                          ? _isInstructorRegistration
                              ? 'Submit your instructor information for administrator verification.'
                              : 'Register your student information to access CASLMS.'
                          : 'Log in using your ID number and password.',
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        color: greyText,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(
                      height: 26,
                    ),
                    _buildModeSelector(),
                    const SizedBox(
                      height: 22,
                    ),

                    if (_isSignUpMode) ...[
                      _label(
                        'Register as',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      _buildAccountTypeSelector(),
                      const SizedBox(
                        height: 20,
                      ),
                      _label(
                        'Full Name',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      TextFormField(
                        controller:
                            _fullNameController,
                        enabled:
                            !_isLoading,
                        textCapitalization:
                            TextCapitalization.words,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            _inputDecoration(
                          hintText:
                              'Enter your full name',
                          icon: Icons
                              .person_outline_rounded,
                        ),
                        validator: (value) {
                          if (!_isSignUpMode) {
                            return null;
                          }

                          final String text =
                              value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'Please enter your full name';
                          }

                          if (text.length < 2) {
                            return 'Enter your complete name';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      _label(
                        'Email Address',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      TextFormField(
                        controller:
                            _emailController,
                        enabled:
                            !_isLoading,
                        keyboardType:
                            TextInputType
                                .emailAddress,
                        autocorrect: false,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            _inputDecoration(
                          hintText:
                              'Enter your Gmail address',
                          icon:
                              Icons.email_outlined,
                        ),
                        validator: (value) {
                          if (!_isSignUpMode) {
                            return null;
                          }

                          final String text =
                              value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'Please enter your email';
                          }

                          if (!_authService
                              .isValidEmail(text)) {
                            return 'Enter a valid email address';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                    ],

                    _label(
                      _isInstructorRegistration
                          ? 'Faculty ID Number'
                          : 'ID Number',
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    TextFormField(
                      controller:
                          _campusIdController,
                      enabled:
                          !_isLoading,
                      keyboardType:
                          TextInputType.number,
                      autocorrect: false,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          _inputDecoration(
                        hintText:
                            _isInstructorRegistration
                                ? 'Enter your faculty ID'
                                : 'e.g. 231577',
                        icon:
                            Icons.badge_outlined,
                      ),
                      validator: (value) {
                        final String text =
                            value?.trim() ?? '';

                        if (text.isEmpty) {
                          return _isInstructorRegistration
                              ? 'Please enter your faculty ID'
                              : 'Please enter your ID number';
                        }

                        if (!_authService
                            .isValidCampusId(text)) {
                          return _isInstructorRegistration
                              ? 'Enter a valid faculty ID'
                              : 'Enter a valid ID number';
                        }

                        return null;
                      },
                    ),

                    if (_isSignUpMode) ...[
                      const SizedBox(
                        height: 18,
                      ),
                      _label(
                        'Department',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      TextFormField(
                        controller:
                            _departmentController,
                        enabled:
                            !_isLoading,
                        textCapitalization:
                            TextCapitalization.words,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            _inputDecoration(
                          hintText:
                              'Enter your department',
                          icon: Icons
                              .account_balance_outlined,
                        ),
                        validator: (value) {
                          if (!_isSignUpMode) {
                            return null;
                          }

                          if ((value?.trim() ?? '')
                              .isEmpty) {
                            return 'Please enter your department';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      _label(
                        _isInstructorRegistration
                            ? 'Position / Program'
                            : 'Course / Program',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      TextFormField(
                        controller:
                            _courseController,
                        enabled:
                            !_isLoading,
                        textCapitalization:
                            TextCapitalization.words,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            _inputDecoration(
                          hintText:
                              _isInstructorRegistration
                                  ? 'e.g. Faculty, BSIT'
                                  : 'e.g. BSIT',
                          icon: _isInstructorRegistration
                              ? Icons.work_outline_rounded
                              : Icons
                                  .school_outlined,
                        ),
                        validator: (value) {
                          if (!_isSignUpMode) {
                            return null;
                          }

                          if ((value?.trim() ?? '')
                              .isEmpty) {
                            return _isInstructorRegistration
                                ? 'Please enter your position or program'
                                : 'Please enter your course or program';
                          }

                          return null;
                        },
                      ),

                      if (_isInstructorRegistration) ...[
                        const SizedBox(
                          height: 18,
                        ),
                        _label(
                          'Faculty ID Document',
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        _buildFacultyIdPicker(),
                      ],
                    ],

                    const SizedBox(
                      height: 18,
                    ),
                    _label(
                      'Password',
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    TextFormField(
                      controller:
                          _passwordController,
                      enabled:
                          !_isLoading,
                      obscureText:
                          !_showPassword,
                      textInputAction:
                          _isSignUpMode
                              ? TextInputAction.next
                              : TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isSignUpMode &&
                            !_isLoading) {
                          _submit();
                        }
                      },
                      decoration:
                          _inputDecoration(
                        hintText:
                            _isSignUpMode
                                ? 'Create your password'
                                : 'Enter your password',
                        icon: Icons
                            .lock_outline_rounded,
                        suffixIcon:
                            IconButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _showPassword =
                                            !_showPassword;
                                      });
                                    },
                          icon: Icon(
                            _showPassword
                                ? Icons
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,
                            color: greyText,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return 'Please enter your password';
                        }

                        if (_isSignUpMode &&
                            value.length < 6) {
                          return 'Password must contain at least 6 characters';
                        }

                        return null;
                      },
                    ),

                    if (_isSignUpMode) ...[
                      const SizedBox(
                        height: 18,
                      ),
                      _label(
                        'Confirm Password',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      TextFormField(
                        controller:
                            _confirmPasswordController,
                        enabled:
                            !_isLoading,
                        obscureText:
                            !_showConfirmPassword,
                        textInputAction:
                            TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            _submit();
                          }
                        },
                        decoration:
                            _inputDecoration(
                          hintText:
                              'Enter your password again',
                          icon:
                              Icons.lock_reset_rounded,
                          suffixIcon:
                              IconButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _showConfirmPassword =
                                              !_showConfirmPassword;
                                        });
                                      },
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,
                              color: greyText,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (!_isSignUpMode) {
                            return null;
                          }

                          if (value == null ||
                              value.isEmpty) {
                            return 'Please confirm your password';
                          }

                          if (value !=
                              _passwordController.text) {
                            return 'Passwords do not match';
                          }

                          return null;
                        },
                      ),
                    ],

                    const SizedBox(
                      height: 28,
                    ),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ||
                                    _isPickingFile
                                ? null
                                : _submit,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              primaryBlue,
                          disabledBackgroundColor:
                              primaryBlue.withValues(
                            alpha: 0.55,
                          ),
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _isSignUpMode
                                    ? _isInstructorRegistration
                                        ? 'Submit for Approval'
                                        : 'Create Account'
                                    : 'Log In',
                                style:
                                    const TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                      FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUpMode
                              ? 'Already registered?'
                              : 'New to CASLMS?',
                          style:
                              const TextStyle(
                            color: greyText,
                          ),
                        ),
                        TextButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                      _switchMode(
                                        !_isSignUpMode,
                                      );
                                    },
                          child: Text(
                            _isSignUpMode
                                ? 'Log In'
                                : 'Create Account',
                            style:
                                const TextStyle(
                              color: primaryBlue,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_isSignUpMode)
                      _buildInformationBox(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding:
          const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:
            const Color(0xFFEEF1F6),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _selectionButton(
              title: 'Log In',
              selected:
                  !_isSignUpMode,
              onTap: () {
                _switchMode(false);
              },
            ),
          ),
          Expanded(
            child: _selectionButton(
              title: 'Sign Up',
              selected:
                  _isSignUpMode,
              onTap: () {
                _switchMode(true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTypeSelector() {
    return Container(
      padding:
          const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:
            const Color(0xFFEEF1F6),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _selectionButton(
              title: 'Student',
              icon:
                  Icons.school_outlined,
              selected:
                  _registrationAccountType ==
                      RegistrationAccountType
                          .student,
              onTap: () {
                _selectAccountType(
                  RegistrationAccountType
                      .student,
                );
              },
            ),
          ),
          Expanded(
            child: _selectionButton(
              title: 'Instructor',
              icon: Icons
                  .co_present_outlined,
              selected:
                  _registrationAccountType ==
                      RegistrationAccountType
                          .instructor,
              onTap: () {
                _selectAccountType(
                  RegistrationAccountType
                      .instructor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        padding:
            const EdgeInsets.symmetric(
          vertical: 11,
          horizontal: 8,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black
                        .withValues(
                      alpha: 0.05,
                    ),
                    blurRadius: 8,
                    offset:
                        const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: selected
                    ? primaryBlue
                    : greyText,
                size: 18,
              ),
              const SizedBox(width: 7),
            ],
            Text(
              title,
              style: TextStyle(
                color: selected
                    ? primaryBlue
                    : greyText,
                fontWeight: selected
                    ? FontWeight.w800
                    : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyIdPicker() {
    final FacultyIdDocument? document =
        _facultyIdDocument;

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: document == null
            ? Colors.white
            : const Color(
                0xFFF2FBF5,
              ),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: document == null
              ? borderColor
              : green.withValues(
                  alpha: 0.45,
                ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          if (document == null)
            const Row(
              children: [
                Icon(
                  Icons
                      .badge_outlined,
                  color: greyText,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Upload a clear photo or PDF of your faculty ID.',
                    style: TextStyle(
                      color: greyText,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(
                  Icons
                      .check_circle_rounded,
                  color: green,
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: darkText,
                          fontWeight:
                              FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        '${document.sizeInMegabytes.toStringAsFixed(2)} MB',
                        style:
                            const TextStyle(
                          color: greyText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip:
                      'Remove file',
                  onPressed:
                      _isLoading
                          ? null
                          : () {
                              setState(() {
                                _facultyIdDocument =
                                    null;
                              });
                            },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: greyText,
                  ),
                ),
              ],
            ),
          const SizedBox(
            height: 12,
          ),
          OutlinedButton.icon(
            onPressed:
                _isLoading ||
                        _isPickingFile
                    ? null
                    : _pickFacultyId,
            icon: _isPickingFile
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons
                        .upload_file_rounded,
                  ),
            label: Text(
              document == null
                  ? 'Choose Faculty ID'
                  : 'Choose Another File',
            ),
          ),
          const SizedBox(
            height: 7,
          ),
          const Text(
            'Accepted: JPG, PNG, WEBP, or PDF — maximum 5 MB',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: greyText,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationBox() {
    return Container(
      margin:
          const EdgeInsets.only(
        top: 8,
      ),
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: primaryBlue,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _isInstructorRegistration
                  ? 'Instructor accounts require a valid faculty ID and administrator approval. You cannot access instructor features while the application is pending.'
                  : 'Student accounts become active immediately after successful registration.',
              style:
                  const TextStyle(
                color: greyText,
                fontSize: 10.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(
    String text,
  ) {
    return Text(
      text,
      style: const TextStyle(
        color: darkText,
        fontSize: 12.5,
        fontWeight:
            FontWeight.w700,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle:
          const TextStyle(
        color: Color(0xFF98A1B2),
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: greyText,
        size: 21,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color: borderColor,
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color: borderColor,
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color: primaryBlue,
          width: 1.6,
        ),
      ),
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color: red,
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color: red,
          width: 1.6,
        ),
      ),
    );
  }
}