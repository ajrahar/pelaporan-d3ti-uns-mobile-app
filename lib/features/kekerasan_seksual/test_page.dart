import 'package:flutter/material.dart';
import 'package:flutter_recaptcha_v2_compat/flutter_recaptcha_v2_compat.dart';

class RecaptchaTestPage extends StatefulWidget {
  const RecaptchaTestPage({Key? key}) : super(key: key);

  @override
  _RecaptchaTestPageState createState() => _RecaptchaTestPageState();
}

class _RecaptchaTestPageState extends State<RecaptchaTestPage> {
  // Create a RecaptchaV2Controller
  RecaptchaV2Controller recaptchaV2Controller = RecaptchaV2Controller();
  bool recaptchaVerified = false;
  String? recaptchaError;
  bool isSubmitting = false;

  // Test form submission
  void submitForm() async {
    if (!recaptchaVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please complete reCAPTCHA verification')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    // Simulate form submission
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      isSubmitting = false;
    });

    // Show success message
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Success'),
          content:
              Text('Form submitted successfully with reCAPTCHA verification!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                resetForm();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Reset the form and reCAPTCHA
  void resetForm() {
    recaptchaV2Controller.reload();
    setState(() {
      recaptchaVerified = false;
      recaptchaError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reCAPTCHA Test Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'reCAPTCHA Test',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              // Test description
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This is a test page for the reCAPTCHA v2 implementation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try clicking the checkbox below. After verification, you should be able to submit the form.',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // reCAPTCHA Section
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'reCAPTCHA Verification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Please verify you are not a robot by checking the box below:',
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 16),

                      // reCAPTCHA Widget
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        constraints: BoxConstraints(maxHeight: 120),
                        child: RecaptchaV2(
                          apiKey:
                              "6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI", // Google's test site key
                          apiSecret:
                              "6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe", // Google's test secret key
                          controller: recaptchaV2Controller,
                          padding: EdgeInsets.all(8),
                          onVerifiedSuccessfully: (success) {
                            setState(() {
                              recaptchaVerified = success;
                              recaptchaError = null;
                            });
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'reCAPTCHA verification successful!')),
                              );
                            } else {
                              setState(() {
                                recaptchaError = 'Verification failed';
                              });
                            }
                          },
                          onVerifiedError: (err) {
                            print('reCAPTCHA error: $err');
                            setState(() {
                              recaptchaVerified = false;
                              recaptchaError = 'Verification error: $err';
                            });
                          },
                        ),
                      ),

                      // Verification Status
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: recaptchaVerified
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: recaptchaVerified
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              recaptchaVerified
                                  ? Icons.check_circle
                                  : Icons.info,
                              color: recaptchaVerified
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                recaptchaVerified
                                    ? 'Verification successful! You can now submit the form.'
                                    : 'Please complete the reCAPTCHA verification.',
                                style: TextStyle(
                                  color: recaptchaVerified
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Error message if any
                      if (recaptchaError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            recaptchaError!,
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Debug Information
              Card(
                elevation: 2,
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                          'reCAPTCHA Verified: ${recaptchaVerified ? "Yes" : "No"}'),
                      if (recaptchaError != null)
                        Text('Error: $recaptchaError'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Form Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: resetForm,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Reset'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: recaptchaVerified && !isSubmitting
                          ? submitForm
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                      ),
                      child: isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('Submit Form'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
