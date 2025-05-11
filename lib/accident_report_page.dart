import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

class AccidentReportPage extends StatefulWidget {
  final String vehicleId;

  const AccidentReportPage({Key? key, required this.vehicleId})
    : super(key: key);

  @override
  _AccidentReportPageState createState() => _AccidentReportPageState();
}

class _AccidentReportPageState extends State<AccidentReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _damagedPartsController = TextEditingController();
  final _repairCostController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<dynamic> _accidentImages = []; // Can hold File objects or XFile objects
  final ImagePicker _picker = ImagePicker();

  // Vehicle data
  double _vehicleValue = 0.0;
  String _vehicleModel = '';
  String _vehicleReg = '';

  // Calculated values
  double _repairCost = 0.0;
  bool _isHeavyDamage = false;
  double _damagePercentage = 0.0;
  double _newConsumptionRate = 0.10; // Default 10%

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    _damagedPartsController.dispose();
    _repairCostController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleData() async {
    try {
      final vehicleDoc =
          await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(widget.vehicleId)
              .get();

      if (vehicleDoc.exists) {
        final data = vehicleDoc.data()!;
        setState(() {
          _vehicleValue = data['currentValue'] ?? 0.0;
          _vehicleModel = data['model'] ?? 'Unknown';
          _vehicleReg = data['registrationNumber'] ?? 'Unknown';
        });
      }
    } catch (e) {
      print('Error loading vehicle data: $e');
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      });
    }
  }

  bool get _isWeb => kIsWeb;

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage();
      if (images != null && images.isNotEmpty) {
        setState(() {
          if (_isWeb) {
            // For web, just store the XFile objects directly
            _accidentImages.addAll(images);
          } else {
            // For mobile, convert to File objects
            _accidentImages.addAll(
              images.map((xFile) => File(xFile.path)).toList(),
            );
          }
        });
        
        print('Added ${images.length} images. Total: ${_accidentImages.length}');
      }
    } catch (e) {
      print('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _accidentImages.removeAt(index);
    });
  }

  void _calculateDamage() {
    if (_repairCostController.text.isEmpty || _vehicleValue == 0) {
      return;
    }

    // Add validation to ensure the text can be parsed as a double
    double repairCost;
    try {
      repairCost = double.parse(_repairCostController.text);
    } catch (e) {
      print('Invalid repair cost format: ${_repairCostController.text}');
      // Set a default value or show an error
      repairCost = 0.0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid repair cost'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }

    double damagePercentage = (_vehicleValue > 0) 
        ? (repairCost / _vehicleValue) * 100 
        : 0.0;
    bool isHeavyDamage = damagePercentage > 40;
    
    setState(() {
      _repairCost = repairCost;
      _damagePercentage = damagePercentage;
      _isHeavyDamage = isHeavyDamage;
      _newConsumptionRate = isHeavyDamage ? 0.15 : 0.10; // 15% if heavy damage, 10% otherwise
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accidentImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one accident image'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Calculate damage before submission
      _calculateDamage();

      // TEMPORARY: Use placeholder URLs instead of actual uploads
      List<String> imageUrls = ["https://via.placeholder.com/150"];

      // Save accident report to Firestore
      final reportRef = await FirebaseFirestore.instance.collection('accident_reports').add({
        'userId': user.uid,
        'vehicleId': widget.vehicleId,
        'accidentDate': Timestamp.fromDate(_selectedDate),
        'description': _descriptionController.text,
        'damagedParts': _damagedPartsController.text,
        'damageCost': _repairCost,
        'vehicleValue': _vehicleValue,
        'damagePercentage': _damagePercentage,
        'heavyDamage': _isHeavyDamage,
        'newConsumptionRate': _newConsumptionRate,
        'imageUrls': imageUrls, // Using placeholder for now
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update vehicle with new consumption rate if heavy damage
      if (_isHeavyDamage) {
        await FirebaseFirestore.instance
            .collection('vehicles')
            .doc(widget.vehicleId)
            .update({
              'consumptionRate': _newConsumptionRate,
              'hadAccident': true,
            });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accident report submitted successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error submitting accident report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report Accident'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle info card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Model:'),
                          Text(
                            _vehicleModel,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Registration:'),
                          Text(
                            _vehicleReg,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Current Value:'),
                          Text(
                            '\$${_vehicleValue.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              Text(
                'Accident Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              SizedBox(height: 16),

              // Date field
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Accident Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.calendar_month),
                    onPressed: () => _pickDate(context),
                  ),
                ),
                readOnly: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter accident date';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Accident Description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter accident description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // Damaged parts field
              TextFormField(
                controller: _damagedPartsController,
                decoration: InputDecoration(
                  labelText: 'Damaged Parts',
                  prefixIcon: Icon(Icons.car_repair),
                  hintText: 'e.g. Front bumper, headlights, hood',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter damaged parts';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // Repair cost field
              TextFormField(
                controller: _repairCostController,
                decoration: InputDecoration(
                  labelText: 'Estimated Repair Cost',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter repair cost';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid cost';
                  }
                  return null;
                },
                onChanged: (_) => _calculateDamage(),
              ),
              SizedBox(height: 24),

              // Damage calculation card
              if (_repairCost > 0)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color:
                      _isHeavyDamage
                          ? AppTheme.errorRed.withOpacity(0.1)
                          : Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Damage Assessment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                _isHeavyDamage
                                    ? AppTheme.errorRed
                                    : AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Repair Cost:'),
                            Text(
                              '\$${_repairCost.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Damage Percentage:'),
                            Text(
                              '${_damagePercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    _isHeavyDamage ? AppTheme.errorRed : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Damage Classification:'),
                            Text(
                              _isHeavyDamage ? 'Heavy Damage' : 'Normal Damage',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    _isHeavyDamage
                                        ? AppTheme.errorRed
                                        : AppTheme.successGreen,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('New Consumption Rate:'),
                            Text(
                              '${(_newConsumptionRate * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    _isHeavyDamage ? AppTheme.errorRed : null,
                              ),
                            ),
                          ],
                        ),
                        if (_isHeavyDamage)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Text(
                              'Note: Heavy damage detected. Consumption rate increased to 15% due to repair costs exceeding 40% of vehicle value.',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: AppTheme.errorRed,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 24),

              Text(
                'Accident Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              SizedBox(height: 8),

              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: Icon(Icons.add_a_photo),
                label: Text('Add Photos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                ),
              ),
              SizedBox(height: 16),

              if (_accidentImages.isNotEmpty)
                Container(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _accidentImages.length,
                    itemBuilder: (context, index) {
                      Widget imageWidget;
                      
                      if (_isWeb) {
                        // For web, use Image.network with XFile.path
                        final item = _accidentImages[index];
                        if (item is XFile) {
                          imageWidget = Image.network(
                            item.path,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading web image: $error');
                              return Container(
                                color: Colors.grey[300],
                                child: Icon(Icons.broken_image, size: 40),
                              );
                            },
                          );
                        } else {
                          // Fallback for web
                          imageWidget = Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.image, size: 40, color: Colors.grey[600]),
                          );
                        }
                      } else {
                        // For mobile platforms
                        final item = _accidentImages[index];
                        if (item is File) {
                          imageWidget = Image.file(
                            item,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image: $error');
                              return Container(
                                color: Colors.grey[300],
                                child: Icon(Icons.broken_image, size: 40),
                              );
                            },
                          );
                        } else {
                          // Fallback for mobile
                          imageWidget = Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.image, size: 40, color: Colors.grey[600]),
                          );
                        }
                      }
                      
                      return Stack(
                        children: [
                          Container(
                            margin: EdgeInsets.only(right: 8),
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageWidget,
                            ),
                          ),
                          Positioned(
                            top: 5,
                            right: 13,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReport,
                  child:
                      _isLoading
                          ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                          : Text(
                            'SUBMIT REPORT',
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
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
