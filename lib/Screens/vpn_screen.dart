import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FakeVPNManager {
  static bool isConnected = false;
  static String selectedCountry = "";
  static String selectedFlag = "";
  static String status = "Disconnected";
  static String stage = "Idle";

  static void connect(String country, String flag) {
    isConnected = true;
    selectedCountry = country;
    selectedFlag = flag;
    status = "Connected";
    stage = "Virtual tunnel active";
  }

  static void disconnect() {
    isConnected = false;
    selectedCountry = "";
    selectedFlag = "";
    status = "Disconnected";
    stage = "Idle";
  }
}

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  bool loading = false;

  final List<Map<String, String>> countries = [
    {"country": "Canada", "flag": "🇨🇦"},
    {"country": "Germany", "flag": "🇩🇪"},
    {"country": "France", "flag": "🇫🇷"},
    {"country": "Poland", "flag": "🇵🇱"},
    {"country": "United Kingdom", "flag": "🇬🇧"},
    {"country": "United States", "flag": "🇺🇸"},
    {"country": "Australia", "flag": "🇦🇺"},
    {"country": "Japan", "flag": "🇯🇵"},
    {"country": "South Korea", "flag": "🇰🇷"},
    {"country": "Singapore", "flag": "🇸🇬"},
    {"country": "Netherlands", "flag": "🇳🇱"},
    {"country": "Brazil", "flag": "🇧🇷"},
    {"country": "India", "flag": "🇮🇳"},
    {"country": "Italy", "flag": "🇮🇹"},
    {"country": "Spain", "flag": "🇪🇸"},
    {"country": "Turkey", "flag": "🇹🇷"},
    {"country": "Sweden", "flag": "🇸🇪"},
    {"country": "Switzerland", "flag": "🇨🇭"},
    {"country": "Russia", "flag": "🇷🇺"},
    {"country": "South Africa", "flag": "🇿🇦"},
  ];

  String? selectedCountry = FakeVPNManager.selectedCountry;

  // ---------------- CONNECT ----------------
  void connectFakeVPN() async {
    if (selectedCountry == null || selectedCountry!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Select a region first")));
      return;
    }

    setState(() => loading = true);

    await Future.delayed(const Duration(seconds: 2)); // fake delay

    final data = countries.firstWhere(
          (c) => c["country"] == selectedCountry,
    );

    FakeVPNManager.connect(data["country"]!, data["flag"]!);

    // UPDATE FIRESTORE
    await FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .update({
      "vpnLocation": data["country"],
      "isVPNConnected": true,
    });

    setState(() => loading = false);
  }

  // ---------------- DISCONNECT ----------------
  void disconnectFakeVPN() async {
    FakeVPNManager.disconnect();

    // UPDATE FIRESTORE
    await FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .update({
      "isVPNConnected": false,
      "vpnLocation": "Unknown",
    });

    setState(() {});
  }

  // ---------------- TILE UI ----------------
  Widget regionTile(String country, String flag) {
    final active = selectedCountry == country;

    return GestureDetector(
      onTap: () => setState(() {
        selectedCountry = country;
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: active ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                country,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (active) const Icon(Icons.check, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final connected = FakeVPNManager.isConnected;
    final statusColor = connected ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Virtual Location VPN"),
      ),

      body: Column(
        children: [
          const SizedBox(height: 10),

          // ---------------- STATUS CARD ----------------
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: statusColor, size: 30),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? "Location: ${FakeVPNManager.selectedCountry}"
                          : "Location: Unknown",
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      connected
                          ? "Stage: ${FakeVPNManager.stage}"
                          : "Stage: Idle",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ---------------- COUNTRY LIST ----------------
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                for (var c in countries) regionTile(c["country"]!, c["flag"]!),
              ],
            ),
          ),

          // ---------------- CONNECT BUTTON ----------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ElevatedButton(
              onPressed: loading
                  ? null
                  : connected
                  ? disconnectFakeVPN
                  : connectFakeVPN,
              style: ElevatedButton.styleFrom(
                backgroundColor: connected ? Colors.red : Colors.blue,
                minimumSize: const Size(double.infinity, 52),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                connected ? "Disconnect" : "Connect",
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
