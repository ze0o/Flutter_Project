import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAccidentReportsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final reports =
        FirebaseFirestore.instance
            .collection('accident_reports')
            .orderBy('timestamp', descending: true)
            .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text("Accident Reports")),
      body: StreamBuilder(
        stream: reports,
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text("No accident reports yet."));
          }
          return ListView(
            children:
                docs.map((doc) {
                  return Card(
                    margin: EdgeInsets.all(10),
                    child: ListTile(
                      title: Text("Vehicle ID: ${doc['vehicleId']}"),
                      subtitle: Text(doc['description']),
                      trailing: Text(
                        "${doc['timestamp'] != null ? (doc['timestamp'] as Timestamp).toDate().toString().split(' ')[0] : ''}",
                      ),
                    ),
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}
