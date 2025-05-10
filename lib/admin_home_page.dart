import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_page.dart';
import 'admin_accident_reports_page.dart';

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final TextEditingController _newAdminEmailController =
      TextEditingController();
  final TextEditingController _newAdminPasswordController =
      TextEditingController();

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  Future<void> _createNewAdmin(BuildContext context) async {
    final email = _newAdminEmailController.text.trim();
    final password = _newAdminPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter both email and password.")),
      );
      return;
    }

    const apiKey = 'AIzaSyBrPvKdNX28B85l9ynlecMYrHRYskFjHGc';

    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final uid = data['localId'];

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email,
          'role': 'Admin',
        });

        _showSuccessDialog(email);
      } else {
        final error = jsonDecode(response.body)['error']['message'];
        _showErrorDialog("Failed to create user: $error");
      }
    } catch (e) {
      _showErrorDialog("An error occurred: ${e.toString()}");
    }
  }

  void _showSuccessDialog(String email) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("✅ Success"),
            content: Text("Admin '$email' created successfully."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("❌ Error"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Insurance Requests"),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            tooltip: "Add Admin",
            onPressed: () => _showCreateAdminDialog(),
          ),
          IconButton(
            icon: Icon(Icons.report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminAccidentReportsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('insurance_requests')
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          return AnimatedList(
            key: _listKey,
            initialItemCount: docs.length,
            itemBuilder: (context, index, animation) {
              final request = docs[index];
              final status = request['status'] ?? '';
              final approved =
                  request.data().toString().contains('adminApproved')
                      ? request['adminApproved']
                      : false;

              return SizeTransition(
                sizeFactor: animation,
                child: FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('vehicles')
                          .doc(request['vehicleId'])
                          .get(),
                  builder: (context, vehicleSnapshot) {
                    if (!vehicleSnapshot.hasData) {
                      return ListTile(title: Text("Loading vehicle info..."));
                    }

                    final vehicleData =
                        vehicleSnapshot.data!.data() as Map<String, dynamic>?;

                    if (vehicleData == null) {
                      return ListTile(title: Text("Vehicle info not found"));
                    }

                    final model = vehicleData['model'] ?? "Unknown";
                    final regNo =
                        vehicleData['registrationNumber'] ?? "Unknown";

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: ListTile(
                        title: Text("Vehicle: $model (Reg: $regNo)"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Depreciated Value: \$${request['depreciatedValue'].toStringAsFixed(2)}",
                            ),
                            if (status.isNotEmpty) Text("Status: $status"),
                            if (status == "Paid" && approved == false)
                              ElevatedButton(
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('insurance_requests')
                                      .doc(request.id)
                                      .update({
                                        'adminApproved': true,
                                        'status': 'Approved',
                                      });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Policy approved.")),
                                  );
                                },
                                child: Text("Approve Policy"),
                              ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          child: Text("Create Offers"),
                          onPressed: () {
                            _showOfferDialog(
                              context,
                              request.id,
                              request['depreciatedValue'],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateAdminDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Create New Admin"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newAdminEmailController,
                decoration: InputDecoration(labelText: "Admin Email"),
              ),
              TextField(
                controller: _newAdminPasswordController,
                decoration: InputDecoration(labelText: "Admin Password"),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text("Create"),
              onPressed: () async {
                Navigator.pop(context);
                await _createNewAdmin(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showOfferDialog(
    BuildContext context,
    String requestId,
    double baseValue,
  ) {
    final offer1Controller = TextEditingController(
      text: (baseValue * 1.0).toStringAsFixed(2),
    );
    final offer2Controller = TextEditingController(
      text: (baseValue * 1.1).toStringAsFixed(2),
    );
    final offer3Controller = TextEditingController(
      text: (baseValue * 1.2).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Create 3 Offers"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: offer1Controller,
                decoration: InputDecoration(labelText: "Basic Offer"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: offer2Controller,
                decoration: InputDecoration(labelText: "Standard Offer"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: offer3Controller,
                decoration: InputDecoration(labelText: "Premium Offer"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('insurance_requests')
                    .doc(requestId)
                    .update({
                      'offers': {
                        'Basic': double.parse(offer1Controller.text),
                        'Standard': double.parse(offer2Controller.text),
                        'Premium': double.parse(offer3Controller.text),
                      },
                      'status': 'Offers Created',
                    });
                Navigator.pop(context);
              },
              child: Text("Save Offers"),
            ),
          ],
        );
      },
    );
  }
}
