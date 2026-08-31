import 'package:flutter/material.dart';

import '../services/campus_auth_service.dart';

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
  // ============================================================
  // DESIGN
  // ============================================================

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

  // ============================================================
  // SERVICE
  // ============================================================

  final CampusAuthService _authService =
      CampusAuthService();

  // ============================================================
  // FORM
  // ============================================================

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

  // ============================================================
  // STATE
  // ============================================================

  bool _isSignUpMode = false;

  bool _isLoading = false;

  bool _showPassword = false;

  bool _showConfirmPassword = false;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _fullNameController.dispose();

    _emailController.dispose();

    _campusIdController.dispose();

    _departmentController.dispose();

    _courseController.dispose();

    _passwordController.dispose();

    _confirmPasswordController
        .dispose();

    super.dispose();
  }

  // ============================================================
  // MODE
  // ============================================================

  void _switchMode(
    bool signUp,
  ) {
    if (_isLoading ||
        signUp == _isSignUpMode) {
      return;
    }

    FocusScope.of(context)
        .unfocus();

    _formKey.currentState
        ?.reset();

    setState(() {
      _isSignUpMode =
          signUp;

      _showPassword =
          false;

      _showConfirmPassword =
          false;

      _passwordController
          .clear();

      _confirmPasswordController
          .clear();
    });
  }

  // ============================================================
  // LOGIN
  //
  // After successful Firebase login, go back to a completely
  // fresh SessionGate.
  //
  // SessionGate handles:
  //
  // student    -> Student Dashboard
  // instructor -> Instructor Dashboard
  // admin      -> Admin Dashboard
  // ============================================================

  Future<void> _handleLogin() async {
    if (_isLoading) {
      return;
    }

    if (!(_formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    FocusScope.of(context)
        .unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signIn(
        campusId:
            _campusIdController
                .text,

        password:
            _passwordController
                .text,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // LOGIN SUCCESS
      //
      // Delete the old Landing/Auth routes and start again from
      // SessionGate.
      // ========================================================

      Navigator.of(context)
          .pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } on CampusAuthException catch (e) {
      if (!mounted) {
        return;
      }

      _showError(
        e.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError(
        'Unable to log in. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading =
              false;
        });
      }
    }
  }

  // ============================================================
  // SIGN UP
  //
  // IMPORTANT:
  //
  // We DO NOT sign out after successful registration.
  //
  // Firebase creates the account and automatically logs in the
  // new student. We immediately return to SessionGate.
  // ============================================================

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
        _confirmPasswordController
            .text) {
      _showError(
        'Passwords do not match.',
      );

      return;
    }

    FocusScope.of(context)
        .unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService
          .signUpStudent(
        fullName:
            _fullNameController
                .text,

        email:
            _emailController
                .text,

        campusId:
            _campusIdController
                .text,

        department:
            _departmentController
                .text,

        course:
            _courseController
                .text,

        password:
            _passwordController
                .text,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // REGISTRATION SUCCESS
      //
      // Firebase user remains authenticated.
      //
      // Public registration creates:
      //
      // role   = student
      // status = active
      //
      // SessionGate will therefore open StudentMainScreen.
      // ========================================================

      Navigator.of(context)
          .pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } on CampusAuthException catch (e) {
      if (!mounted) {
        return;
      }

      _showError(
        e.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError(
        'Unable to create your account. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading =
              false;
        });
      }
    }
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submit() async {
    if (_isSignUpMode) {
      await _handleSignUp();
    } else {
      await _handleLogin();
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),

        backgroundColor:
            red,

        behavior:
            SnackBarBehavior
                .floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,

      appBar: AppBar(
        backgroundColor:
            background,

        elevation: 0,

        foregroundColor:
            darkText,
      ),

      body: SafeArea(
        top: false,

        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 520,
            ),

            child:
                SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),

              padding:
                  const EdgeInsets
                      .fromLTRB(
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
                    // ==========================================
                    // LOGO
                    // ==========================================

                    Center(
                      child: Container(
                        width: 78,

                        height: 78,

                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white,

                          borderRadius:
                              BorderRadius
                                  .circular(
                            22,
                          ),

                          border:
                              Border.all(
                            color:
                                borderColor,
                          ),

                          image:
                              const DecorationImage(
                            image:
                                AssetImage(
                              'assets/images/CASlogo.jpg',
                            ),

                            fit:
                                BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ==========================================
                    // TITLE
                    // ==========================================

                    Text(
                      _isSignUpMode
                          ? 'Create your account'
                          : 'Welcome back',

                      textAlign:
                          TextAlign.center,

                      style:
                          const TextStyle(
                        color:
                            darkText,

                        fontSize:
                            27,

                        fontWeight:
                            FontWeight
                                .w800,

                        letterSpacing:
                            -0.7,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      _isSignUpMode
                          ? 'Register your student information to access CASLMS.'
                          : 'Log in using your ID number and password.',

                      textAlign:
                          TextAlign.center,

                      style:
                          const TextStyle(
                        color:
                            greyText,

                        fontSize:
                            13,

                        height:
                            1.5,
                      ),
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    // ==========================================
                    // LOGIN / SIGN UP SELECTOR
                    // ==========================================

                    _buildModeSelector(),

                    const SizedBox(
                      height: 24,
                    ),

                    // ==========================================
                    // FULL NAME
                    // ==========================================

                    if (_isSignUpMode) ...[
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
                            TextCapitalization
                                .words,

                        textInputAction:
                            TextInputAction
                                .next,

                        decoration:
                            _inputDecoration(
                          hintText:
                              'Enter your full name',

                          icon:
                              Icons
                                  .person_outline_rounded,
                        ),

                        validator:
                            (value) {
                          if (!_isSignUpMode) {
                            return null;
                          }

                          if (value ==
                                  null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Please enter your full name';
                          }

                          if (value
                                  .trim()
                                  .length <
                              2) {
                            return 'Enter your complete name';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      // ========================================
                      // REAL EMAIL
                      // ========================================

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

                        autocorrect:
                            false,

                        textInputAction:
                            TextInputAction
                                .next,

                        decoration:
                            _inputDecoration(
                          hintText:
                              'Enter your email address',

                          icon:
                              Icons
                                  .email_outlined,
                        ),

                        validator:
                            (value) {
                          if (!_isSignUpMode) {
                            return null;
                          }

                          if (value ==
                                  null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Please enter your email';
                          }

                          if (!_authService
                              .isValidEmail(
                            value,
                          )) {
                            return 'Enter a valid email address';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 18,
                      ),
                    ],

                    // ==========================================
                    // ID NUMBER
                    // ==========================================

                    _label(
                      'ID Number',
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
                          TextInputType
                              .number,

                      autocorrect:
                          false,

                      textInputAction:
                          TextInputAction
                              .next,

                      decoration:
                          _inputDecoration(
                        hintText:
                            'e.g. 231577',

                        icon:
                            Icons
                                .badge_outlined,
                      ),

                      validator:
                          (value) {
                        if (value ==
                                null ||
                            value
                                .trim()
                                .isEmpty) {
                          return 'Please enter your ID number';
                        }

                        if (!_authService
                            .isValidCampusId(
                          value,
                        )) {
                          return 'Enter a valid ID number';
                        }

                        return null;
                      },
                    ),

                    // ==========================================
                    // DEPARTMENT + COURSE
                    // ==========================================

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
                            TextCapitalization
                                .words,

                        textInputAction:
                            TextInputAction
                                .next,

                        decoration:
                            _inputDecoration(
                          hintText:
                              'Enter your department',

                          icon:
                              Icons
                                  .account_balance_outlined,
                        ),

                        validator:
                            (value) {
                          if (!_isSignUpMode) {
                            return null;
                          }

                          if (value ==
                                  null ||
                              value
                                  .trim()
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
                        'Course',
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
                            TextCapitalization
                                .words,

                        textInputAction:
                            TextInputAction
                                .next,

                        decoration:
                            _inputDecoration(
                          hintText:
                              'e.g. BS Information Technology',

                          icon:
                              Icons
                                  .menu_book_outlined,
                        ),

                        validator:
                            (value) {
                          if (!_isSignUpMode) {
                            return null;
                          }

                          if (value ==
                                  null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Please enter your course';
                          }

                          return null;
                        },
                      ),
                    ],

                    // ==========================================
                    // PASSWORD
                    // ==========================================

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
                              ? TextInputAction
                                  .next
                              : TextInputAction
                                  .done,

                      onFieldSubmitted:
                          (_) {
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

                        icon:
                            Icons
                                .lock_outline_rounded,

                        suffixIcon:
                            IconButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                      setState(
                                        () {
                                          _showPassword =
                                              !_showPassword;
                                        },
                                      );
                                    },

                          icon:
                              Icon(
                            _showPassword
                                ? Icons
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,

                            color:
                                greyText,
                          ),
                        ),
                      ),

                      validator:
                          (value) {
                        if (value ==
                                null ||
                            value.isEmpty) {
                          return 'Please enter your password';
                        }

                        if (_isSignUpMode &&
                            value.length <
                                6) {
                          return 'Password must contain at least 6 characters';
                        }

                        return null;
                      },
                    ),

                    // ==========================================
                    // CONFIRM PASSWORD
                    // ==========================================

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
                            TextInputAction
                                .done,

                        onFieldSubmitted:
                            (_) {
                          if (!_isLoading) {
                            _submit();
                          }
                        },

                        decoration:
                            _inputDecoration(
                          hintText:
                              'Enter your password again',

                          icon:
                              Icons
                                  .lock_reset_rounded,

                          suffixIcon:
                              IconButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : () {
                                        setState(
                                          () {
                                            _showConfirmPassword =
                                                !_showConfirmPassword;
                                          },
                                        );
                                      },

                            icon:
                                Icon(
                              _showConfirmPassword
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,

                              color:
                                  greyText,
                            ),
                          ),
                        ),

                        validator:
                            (value) {
                          if (!_isSignUpMode) {
                            return null;
                          }

                          if (value ==
                                  null ||
                              value.isEmpty) {
                            return 'Please confirm your password';
                          }

                          if (value !=
                              _passwordController
                                  .text) {
                            return 'Passwords do not match';
                          }

                          return null;
                        },
                      ),
                    ],

                    const SizedBox(
                      height: 28,
                    ),

                    // ==========================================
                    // SUBMIT BUTTON
                    // ==========================================

                    SizedBox(
                      height: 56,

                      child:
                          ElevatedButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _submit,

                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              primaryBlue,

                          disabledBackgroundColor:
                              primaryBlue
                                  .withValues(
                            alpha:
                                0.55,
                          ),

                          elevation:
                              0,

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                          ),
                        ),

                        child:
                            _isLoading
                                ? const SizedBox(
                                    width:
                                        22,

                                    height:
                                        22,

                                    child:
                                        CircularProgressIndicator(
                                      color:
                                          Colors.white,

                                      strokeWidth:
                                          2.5,
                                    ),
                                  )
                                : Text(
                                    _isSignUpMode
                                        ? 'Create Account'
                                        : 'Log In',

                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,

                                      fontWeight:
                                          FontWeight.w800,

                                      fontSize:
                                          15,
                                    ),
                                  ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ==========================================
                    // SWITCH LOGIN / SIGN UP
                    // ==========================================

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,

                      children: [
                        Text(
                          _isSignUpMode
                              ? 'Already registered?'
                              : 'New to CASLMS?',

                          style:
                              const TextStyle(
                            color:
                                greyText,
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
                              color:
                                  primaryBlue,

                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ==========================================
                    // SIGN-UP INFORMATION
                    // ==========================================

                    if (_isSignUpMode)
                      Container(
                        margin:
                            const EdgeInsets
                                .only(
                          top: 8,
                        ),

                        padding:
                            const EdgeInsets
                                .all(
                          13,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              lightBlue,

                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),

                        child:
                            const Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            Icon(
                              Icons
                                  .info_outline_rounded,

                              color:
                                  primaryBlue,

                              size:
                                  18,
                            ),

                            SizedBox(
                              width: 9,
                            ),

                            Expanded(
                              child:
                                  Text(
                                'Student accounts can register here. Instructor and Admin accounts are created separately.',

                                style:
                                    TextStyle(
                                  color:
                                      greyText,

                                  fontSize:
                                      10.5,

                                  height:
                                      1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MODE SELECTOR
  // ============================================================

  Widget _buildModeSelector() {
    return Container(
      padding:
          const EdgeInsets.all(
        4,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFEEF1F6,
        ),

        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),

      child: Row(
        children: [
          Expanded(
            child:
                _modeButton(
              title:
                  'Log In',

              selected:
                  !_isSignUpMode,

              onTap:
                  () {
                _switchMode(
                  false,
                );
              },
            ),
          ),

          Expanded(
            child:
                _modeButton(
              title:
                  'Sign Up',

              selected:
                  _isSignUpMode,

              onTap:
                  () {
                _switchMode(
                  true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MODE BUTTON
  // ============================================================

  Widget _modeButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap:
          onTap,

      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds:
              180,
        ),

        padding:
            const EdgeInsets
                .symmetric(
          vertical:
              11,
        ),

        alignment:
            Alignment.center,

        decoration:
            BoxDecoration(
          color:
              selected
                  ? Colors.white
                  : Colors
                      .transparent,

          borderRadius:
              BorderRadius
                  .circular(
            11,
          ),

          boxShadow:
              selected
                  ? [
                      BoxShadow(
                        color:
                            Colors.black
                                .withValues(
                          alpha:
                              0.05,
                        ),

                        blurRadius:
                            8,

                        offset:
                            const Offset(
                          0,
                          2,
                        ),
                      ),
                    ]
                  : [],
        ),

        child: Text(
          title,

          style:
              TextStyle(
            color:
                selected
                    ? primaryBlue
                    : greyText,

            fontWeight:
                selected
                    ? FontWeight
                        .w800
                    : FontWeight
                        .w600,

            fontSize:
                13,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LABEL
  // ============================================================

  Widget _label(
    String text,
  ) {
    return Text(
      text,

      style:
          const TextStyle(
        color:
            darkText,

        fontSize:
            12.5,

        fontWeight:
            FontWeight.w700,
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText:
          hintText,

      hintStyle:
          const TextStyle(
        color:
            Color(
          0xFFA0A8B7,
        ),

        fontSize:
            13,
      ),

      prefixIcon:
          Icon(
        icon,

        color:
            greyText,

        size:
            21,
      ),

      suffixIcon:
          suffixIcon,

      filled:
          true,

      fillColor:
          Colors.white,

      contentPadding:
          const EdgeInsets
              .symmetric(
        horizontal:
            16,

        vertical:
            17,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          15,
        ),

        borderSide:
            const BorderSide(
          color:
              borderColor,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          15,
        ),

        borderSide:
            const BorderSide(
          color:
              borderColor,

          width:
              1.3,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          15,
        ),

        borderSide:
            const BorderSide(
          color:
              primaryBlue,

          width:
              1.7,
        ),
      ),

      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          15,
        ),

        borderSide:
            const BorderSide(
          color:
              red,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          15,
        ),

        borderSide:
            const BorderSide(
          color:
              red,

          width:
              1.5,
        ),
      ),
    );
  }
}