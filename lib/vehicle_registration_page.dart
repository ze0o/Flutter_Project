import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

class VehicleRegistrationPage extends StatefulWidget {
  @override
  _VehicleRegistrationPageState createState() =>
      _VehicleRegistrationPageState();
}

class _VehicleRegistrationPageState extends State<VehicleRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final modelController = TextEditingController();
  final registrationNumberController = TextEditingController();
  final priceController = TextEditingController();
  final yearController = TextEditingController();
  final chassisNumberController = TextEditingController();
  final passengersController = TextEditingController();
  final driverAgeController = TextEditingController();

  bool _isSubmitting = false;
  bool _hasAccident = false;

  Future<void> registerVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('vehicles').add({
          'userId': user.uid,
          'model': modelController.text.trim(),
          'registrationNumber': registrationNumberController.text.trim(),
          'price': double.tryParse(priceController.text.trim()) ?? 0,
          'year':
              int.tryParse(yearController.text.trim()) ?? DateTime.now().year,
          'chassisNumber': chassisNumberController.text.trim(),
          'passengers': int.tryParse(passengersController.text.trim()) ?? 4,
          'driverAge': int.tryParse(driverAgeController.text.trim()) ?? 30,
          'hasAccident': _hasAccident,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Vehicle registered successfully!"),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error registering vehicle: $e"),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Register Vehicle"), elevation: 0),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryColor.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Vehicle Information",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Please provide accurate details about your vehicle",
                    style: TextStyle(fontSize: 14, color: AppTheme.textLight),
                  ),
                  SizedBox(height: 24),

                  _buildTextField(
                    controller: modelController,
                    label: "Car Model",
                    icon: Icons.directions_car,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter car model';
                      }
                      return null;
                    },
                  ),

                  _buildTextField(
                    controller: registrationNumberController,
                    label: "Registration Number",
                    icon: Icons.confirmation_number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter registration number';
                      }
                      return null;
                    },
                  ),

                  _buildTextField(
                    controller: chassisNumberController,
                    label: "Chassis Number",
                    icon: Icons.numbers,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter chassis number';
                      }
                      return null;
                    },
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: priceController,
                          label: "Price When New",
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter price';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: yearController,
                          label: "Manufacturing Year",
                          icon: Icons.calendar_today,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter year';
                            }
                            final year = int.tryParse(value);
                            if (year == null) {
                              return 'Enter a valid year';
                            }
                            if (year < 1900 || year > DateTime.now().year) {
                              return 'Enter a valid year';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: passengersController,
                          label: "Number of Passengers",
                          icon: Icons.people,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter number';
                            }
                            final num = int.tryParse(value);
                            if (num == null || num < 1) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: driverAgeController,
                          label: "Driver's Age",
                          icon: Icons.person,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter age';
                            }
                            final age = int.tryParse(value);
                            if (age == null || age < 18 || age > 100) {
                              return 'Enter a valid age';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.report_problem_outlined,
                          color: AppTheme.warningOrange,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "Has this vehicle been in an accident before?",
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        Switch(
                          value: _hasAccident,
                          onChanged: (value) {
                            setState(() {
                              _hasAccident = value;
                            });
                          },
                          activeColor: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : registerVehicle,
                      child:
                          _isSubmitting
                              ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              )
                              : Text(
                                "REGISTER VEHICLE",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }
}
