import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InsurancePolicyPage extends StatefulWidget {
  @override
  _InsurancePolicyPageState createState() => _InsurancePolicyPageState();
}

class _InsurancePolicyPageState extends State<InsurancePolicyPage> {
  String search = "";
  final userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final policies =
        FirebaseFirestore.instance
            .collection('insurance_requests')
            .where('status', isEqualTo: 'Paid')
            .where('userId', isEqualTo: userId)
            .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text("Insurance Policies")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Search by year or reg no.",
              ),
              onChanged: (val) => setState(() => search = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: policies,
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) {
                  final reg = doc['vehicleId'].toString().toLowerCase();
                  final year =
                      doc.data().toString().contains('year')
                          ? doc['year'].toString()
                          : '';
                  return reg.contains(search) || year.contains(search);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Text("No paid insurance policies found."),
                  );
                }

                return ListView(
                  children:
                      docs.map((doc) {
                        final offer =
                            doc.data().toString().contains('selectedOffer')
                                ? doc['selectedOffer']
                                : 'N/A';
                        final vehicleId = doc['vehicleId'] ?? '';
                        return Card(
                          child: ListTile(
                            title: Text("Vehicle: $vehicleId"),
                            subtitle: Text(
                              "Selected Offer: $offer\nStatus: ${doc['status']}",
                            ),
                          ),
                        );
                      }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
