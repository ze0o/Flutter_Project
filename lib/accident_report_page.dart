import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AccidentReportPage extends StatefulWidget {
  final String vehicleId;
  const AccidentReportPage({Key? key, required this.vehicleId})
    : super(key: key);

  @override
  _AccidentReportPageState createState() => _AccidentReportPageState();
}

class _AccidentReportPageState extends State<AccidentReportPage> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _costController = TextEditingController();

  bool isLoading = false;

  Future<void> submitAccidentReport() async {
    setState(() => isLoading = true);

    try {
      final description = _descriptionController.text.trim();
      final damageCost = double.tryParse(_costController.text.trim()) ?? 0;

      final carSnapshot =
          await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(widget.vehicleId)
              .get();

      final carValue = carSnapshot.data()?['price'] ?? 0;
      final isHeavy = damageCost >= 0.4 * carValue;

      await FirebaseFirestore.instance.collection('accident_reports').add({
        'vehicleId': widget.vehicleId,
        'description': description,
        'damageCost': damageCost,
        'heavyDamage': isHeavy,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Accident report submitted.")));

      _descriptionController.clear();
      _costController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Report Accident")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: "Description"),
              maxLines: 3,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _costController,
              decoration: InputDecoration(labelText: "Estimated Damage Cost"),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : submitAccidentReport,
              child:
                  isLoading
                      ? CircularProgressIndicator()
                      : Text("Submit Report"),
            ),
          ],
        ),
      ),
    );
  }
}
