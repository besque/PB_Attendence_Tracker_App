import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://error.url.not.set';

class ParticipantModel {
  final String name;
  final String email;
  final String id;
  final String eventName;
  bool isSelected;

  ParticipantModel({
    required this.name,
    required this.email,
    required this.id,
    required this.eventName,
    this.isSelected = true,
  });

  Map<String, dynamic> toJson() => {
        'participant_name': name,
        'participant_email': email,
        'participant_id': id,
        'event_name': eventName,
      };

  factory ParticipantModel.fromJson(Map<String, dynamic> json) => ParticipantModel(
        name: json['participant_name'],
        email: json['participant_email'],
        id: json['participant_id'],
        eventName: json['event_name'],
      );
}

class ParticipantSelectionScreen extends StatefulWidget {
  final String subject;
  final String body;
  final bool includeQR;
  final String eventName;

  const ParticipantSelectionScreen({
    super.key,
    required this.subject,
    required this.body,
    required this.includeQR,
    required this.eventName,
  });

  @override
  State<ParticipantSelectionScreen> createState() => _ParticipantSelectionScreenState();
}

class _ParticipantSelectionScreenState extends State<ParticipantSelectionScreen> {
  List<ParticipantModel> _participants = [];
  bool _isLoading = true;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final url = Uri.parse('$baseUrl/participants?event=${Uri.encodeComponent(widget.eventName)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        setState(() {
          _participants = jsonData.map((item) => ParticipantModel.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        _showErrorDialog('Failed to load participants: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error: $e');
    }
  }

  Future<void> _sendEmails() async {
    final selectedParticipants = _participants.where((p) => p.isSelected).map((p) => p.toJson()).toList();

    if (selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one participant')),
      );
      return;
    }
    
    _showSendingDialog();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-emails'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'subject': widget.subject,
          'body': widget.body,
          'include_qr': widget.includeQR,
          'participants': selectedParticipants,
        }),
      );
      Navigator.of(context).pop();
      final responseData = json.decode(response.body);
      _showResultDialog(response.statusCode == 200 && responseData['success'],
          responseData['message'] ?? 'An unknown error occurred.');
    } catch (e) {
      Navigator.of(context).pop();
      _showResultDialog(false, 'Failed to connect to the server.');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Error'), content: Text(message), actions: [TextButton(child: const Text('OK'), onPressed: () => Navigator.of(c).pop())]));
  }

  void _showSendingDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Sending...")])));
  }

  void _showResultDialog(bool success, String message) {
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(success ? "Success" : "Error"), content: Text(message), actions: [TextButton(onPressed: () { Navigator.of(c).pop(); if(success) Navigator.of(context).pop(); }, child: const Text("OK"))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Recipients for ${widget.eventName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                CheckboxListTile(
                  title: const Text("Select All"),
                  value: _selectAll,
                  onChanged: (bool? value) {
                    setState(() {
                      _selectAll = value ?? false;
                      for (var p in _participants) {
                        p.isSelected = _selectAll;
                      }
                    });
                  },
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      final participant = _participants[index];
                      return CheckboxListTile(
                        title: Text(participant.name),
                        subtitle: Text(participant.email),
                        value: participant.isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            participant.isSelected = value ?? false;
                            if (_participants.every((p) => p.isSelected)) {
                              _selectAll = true;
                            } else {
                              _selectAll = false;
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _sendEmails,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Emails'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
                ),
              ],
            ),
    );
  }
}