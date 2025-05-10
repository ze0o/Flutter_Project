import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InsuranceRequestPage extends StatefulWidget {
  final String vehicleId;
  final double originalPrice;
  final int year;

  InsuranceRequestPage({
    required this.vehicleId,
    required this.originalPrice,
    required this.year,
  });

  @override
  _InsuranceRequestPageState createState() => _InsuranceRequestPageState();
}

class _InsuranceRequestPageState extends State<InsuranceRequestPage>
    with SingleTickerProviderStateMixin {
  String? selectedOffer;
  bool requestExists = false;
  String requestId = "";
  Map offers = {};
  String status = "";

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late Future<void> _loadRequestData;
  late Future<double> _valueFuture;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();

    _valueFuture = calculateDepreciatedValue();
    _loadRequestData = checkRequest();
  }

  Future<double> calculateDepreciatedValue() async {
    final currentYear = DateTime.now().year;
    int yearsOld = currentYear - widget.year;
    double depreciatedPrice = widget.originalPrice;

    final accidentSnapshot =
        await FirebaseFirestore.instance
            .collection('accident_reports')
            .where('vehicleId', isEqualTo: widget.vehicleId)
            .where('heavyDamage', isEqualTo: true)
            .get();

    double rate = accidentSnapshot.docs.isNotEmpty ? 0.85 : 0.90;

    for (int i = 0; i < yearsOld; i++) {
      depreciatedPrice *= rate;
    }

    return depreciatedPrice;
  }

  Future<void> checkRequest() async {
    final query =
        await FirebaseFirestore.instance
            .collection('insurance_requests')
            .where('vehicleId', isEqualTo: widget.vehicleId)
            .get();

    if (query.docs.isNotEmpty) {
      final data = query.docs.first;
      requestExists = true;
      requestId = data.id;
      offers = data['offers'] ?? {};
      selectedOffer = data['selectedOffer'];
      status = data['status'] ?? "";
    } else {
      requestExists = false;
    }
  }

  Future<void> submitRequest() async {
    double depreciatedValue = await calculateDepreciatedValue();
    await FirebaseFirestore.instance.collection('insurance_requests').add({
      'vehicleId': widget.vehicleId,
      'depreciatedValue': depreciatedValue,
      'status': 'Pending',
      'adminApproved': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Insurance request submitted.")));
    setState(() {
      _loadRequestData = checkRequest();
    });
  }

  Future<void> selectOffer(String offerType) async {
    await FirebaseFirestore.instance
        .collection('insurance_requests')
        .doc(requestId)
        .update({'selectedOffer': offerType, 'status': 'Offer Selected'});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Offer selected: $offerType")));
    setState(() {
      _loadRequestData = checkRequest();
    });
  }

  Future<void> simulatePayment() async {
    await FirebaseFirestore.instance
        .collection('insurance_requests')
        .doc(requestId)
        .update({'status': 'Paid'});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Payment simulated successfully.")));
    setState(() {
      _loadRequestData = checkRequest();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Insurance Request")),
      body: FutureBuilder<void>(
        future: _loadRequestData,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<double>(
                    future: _valueFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return CircularProgressIndicator();
                      return Text(
                        "Depreciated Car Value: \$${snapshot.data!.toStringAsFixed(2)}",
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  if (!requestExists)
                    ElevatedButton(
                      onPressed: submitRequest,
                      child: Text("Submit Insurance Request"),
                    ),
                  if (requestExists && offers.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Available Offers:"),
                        for (var offer in offers.entries)
                          ListTile(
                            title: Text("${offer.key}: \$${offer.value}"),
                            trailing: ElevatedButton(
                              onPressed:
                                  selectedOffer == null
                                      ? () => selectOffer(offer.key)
                                      : null,
                              child: Text("Select"),
                            ),
                          ),
                        if (selectedOffer != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Selected Offer: $selectedOffer"),
                              SizedBox(height: 10),
                              if (status == "Approved")
                                Text(
                                  "✅ Your insurance policy has been approved.",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (status == "Paid")
                                Text(
                                  "🕒 Payment received. Waiting for admin approval.",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (status != "Paid" && status != "Approved")
                                ElevatedButton(
                                  onPressed: simulatePayment,
                                  child: Text("Simulate Payment"),
                                ),
                            ],
                          ),
                      ],
                    ),
                  if (requestExists && offers.isEmpty)
                    Text("Waiting for Admin to create offers."),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
