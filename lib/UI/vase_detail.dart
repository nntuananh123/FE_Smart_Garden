import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class VaseDetailScreen extends StatefulWidget {
  final int vaseId;
  final int deviceId;

  const VaseDetailScreen({required this.vaseId, required this.deviceId, Key? key}) : super(key: key);

  @override
  State<VaseDetailScreen> createState() => _VaseDetailScreenState();
}

class _VaseDetailScreenState extends State<VaseDetailScreen> {
  Map<String, dynamic>? vaseData;
  bool loading = true;

  // MQTT fields
  final String _mqttServer = 'je652a4d.ala.asia-southeast1.emqxsl.com';
  final int _mqttPort = 8883;
  final String _mqttClientId = 'flutter_client';
  final String _mqttUsername = 'esp32_device';
  final String _mqttPassword = 'your_password_123';
  final String _topic = 'smart_garden/data';
  final String _clientId = 'FlutterClient';

  late MqttServerClient _client;
  String _moistureValue = 'N/A';
  int? _moisturePercent;
  String _relayState = 'OFF';
  bool _isConnected = false;
  DateTime? _lastToggle;
  final Duration _debounceDuration = Duration(milliseconds: 200);
  bool _isToggling = false;

  // Auto watering
  bool _autoWatering = false;

  @override
  void initState() {
    super.initState();
    fetchVaseDetail();
    _connectToMQTT();
  }

  Future<void> fetchVaseDetail() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final url = Uri.parse('https://chillguys.fun/vase/${widget.vaseId}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          vaseData = jsonDecode(response.body)['data'];
        });
      }
    } catch (e) {
      // handle error
    } finally {
      setState(() => loading = false);
    }
  }

  void _connectToMQTT() async {
    _client = MqttServerClient(_mqttServer, _mqttClientId)
      ..port = _mqttPort
      ..secure = true
      ..setProtocolV311()
      ..logging(on: false);

    _client.onConnected = () {
      _onConnected();
      setState(() {
        _isConnected = true;
      });
    };
    _client.onDisconnected = _onDisconnected;
    _client.onSubscribed = _onSubscribed;

    try {
      await _client.connect(_mqttUsername, _mqttPassword);
    } catch (e) {
      setState(() => _isConnected = false);
    }

    _client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
      final String payload =
      MqttPublishPayload.bytesToStringAsString(message.payload.message);

      if (c[0].topic == _topic) {
        try {
          final Map<String, dynamic> data = jsonDecode(payload);
          setState(() {
            // Only listen to the deviceId assigned to this vase
            if (widget.deviceId == 1) {
              if (data.containsKey('sensor1')) {
                _moistureValue = data['sensor1'].toString() + '%';
                _moisturePercent = int.tryParse(data['sensor1'].toString());
              }
              if (data.containsKey('relay1')) {
                _relayState = data['relay1'].toString();
                _isToggling = false;
              }
            } else if (widget.deviceId == 2) {
              if (data.containsKey('sensor2')) {
                _moistureValue = data['sensor2'].toString() + '%';
                _moisturePercent = int.tryParse(data['sensor2'].toString());
              }
              if (data.containsKey('relay2')) {
                _relayState = data['relay2'].toString();
                _isToggling = false;
              }
            }
          });

          // Auto watering logic
          if (_autoWatering && _isConnected && _moisturePercent != null) {
            String desiredRelay = _relayState;
            if (_moisturePercent! < 30) {
              desiredRelay = 'ON';
            } else {
              desiredRelay = 'OFF';
            }
            if (_relayState != desiredRelay && !_isToggling) {
              _sendRelayCommand(desiredRelay);
            }
          }
        } catch (e) {
          print('Failed to parse JSON: $e');
        }
      }
    });
  }

  void _onConnected() {
    _client.subscribe(_topic, MqttQos.atLeastOnce);
  }

  void _onDisconnected() {
    setState(() {
      _isConnected = false;
    });
  }

  void _onSubscribed(String topic) {}

  void _toggleRelay() {
    if (!_isConnected || _isToggling || _autoWatering) return;
    if (_lastToggle != null &&
        DateTime.now().difference(_lastToggle!) < _debounceDuration) {
      print('Relay toggle ignored due to debounce');
      return;
    }
    setState(() => _isToggling = true);
    final String newState = _relayState == 'ON' ? 'OFF' : 'ON';
    if (_relayState != newState) {
      _sendRelayCommand(newState);
      _lastToggle = DateTime.now();
    }
  }

  void _sendRelayCommand(String state) {
    final Map<String, String> payload = {
      widget.deviceId == 1 ? 'relay1' : 'relay2': state,
      'clientId': _clientId,
    };
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    _client.publishMessage(_topic, MqttQos.exactlyOnce, builder.payload!);
    setState(() => _isToggling = true);
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green[700], size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoistureCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(Icons.water_drop, color: Colors.blue[700], size: 40),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Soil Moisture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    _moistureValue,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelayCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(
              _relayState == 'ON' ? Icons.power : Icons.power_off,
              color: _relayState == 'ON' ? Colors.green : Colors.grey,
              size: 40,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pump Relay State', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    _relayState,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _relayState == 'ON' ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: (_isToggling || _autoWatering) ? null : _toggleRelay,
              style: ElevatedButton.styleFrom(
                backgroundColor: _relayState == 'ON' ? Colors.red : Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: _isToggling
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Text(_relayState == 'ON' ? 'Turn OFF' : 'Turn ON'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoWateringSwitch() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: Text(
          'Auto Watering',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green[700],
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          'Automatically water when soil moisture < 30%',
          style: TextStyle(fontSize: 14),
        ),
        value: _autoWatering,
        onChanged: (val) {
          setState(() {
            _autoWatering = val;
          });
        },
        activeColor: Colors.green,
        inactiveThumbColor: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(vaseData?['vaseName'] ?? 'Vase Detail'),
        centerTitle: true,
        backgroundColor: const Color(0xFF388e3c),
        elevation: 2,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : vaseData == null
          ? const Center(child: Text('Failed to load vase info'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vase image
            if (vaseData!['plant']?['image'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  vaseData?['plant']['image'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 18),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      icon: Icons.eco,
                      label: "Plant:",
                      value: vaseData!['plant']?['plantName'] ?? '',
                    ),
                    _buildInfoRow(
                      icon: Icons.location_on,
                      label: "Area:",
                      value: vaseData!['area']?['areaName'] ?? '',
                    ),
                    _buildInfoRow(
                      icon: Icons.calendar_today,
                      label: "Created:",
                      value: vaseData!['createdAt']?.substring(0, 10) ?? '',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _buildMoistureCard(),
            const SizedBox(height: 18),
            _buildRelayCard(),
            const SizedBox(height: 18),
            _buildAutoWateringSwitch(),
            if (!_isConnected)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Center(
                  child: Text(
                    'Not connected to MQTT broker',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}