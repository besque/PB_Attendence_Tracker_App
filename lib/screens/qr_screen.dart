//qr_screen
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isProcessing = false;
  bool _isSuccess = false;
  String _statusMessage = '';

 

  final List<String> _requiredFields = [
    'participant_name',
    'participant_email',
    'participant_id',
    'event_name'
  ];

  @override
  void initState() {
    super.initState();
    // _loadProcessedIdsAndEmails();
  }


  void _validateRequiredFields(Map<String, dynamic> data) {
    for (var field in _requiredFields) {
      if (!data.containsKey(field) ||
          data[field] == null ||
          data[field].toString().trim().isEmpty) {
        throw Exception('Missing or empty required field: $field');
      }
    }
  }

  Future<void> _updateFirebaseAttendance(
    Map<String, dynamic> attendeeData) async {
  try {
    _validateRequiredFields(attendeeData);

    String eventName = attendeeData['event_name'];
    
    String participantId = attendeeData['participant_id'];

    final now = DateTime.now().toIso8601String();

    final participantDocRef=_firestore
      .collection('events')
      .doc(eventName)
      .collection('participants')
      .doc(participantId);

    final docRef=_firestore.collection('events').doc(eventName);

    
    await _firestore.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(docRef);
      
      

      if (docSnapshot.exists) {
        // update check-in time if the event exists
        transaction.update(docRef, {
          'latest_checkin_activity': now, 
        });
      } else {
        // create event if does not exist
        transaction.set(docRef, {
          'event_name': eventName,
          'created_at': FieldValue.serverTimestamp(),
          'latest_checkin_activity': now,
        });
      }

      Map<String,dynamic> participantRecord={
        'participant_name': attendeeData['participant_name'],
        'participant_email': attendeeData['participant_email'],
        'participant_id': participantId,
        'event_name': eventName,
        'department': attendeeData['department'], 
        'role': attendeeData['role'], 
        'attendance_status': true, 
        'check_in_time': now,
      };

      transaction.set(participantDocRef, participantRecord, SetOptions(merge: true));
    });


    setState(() {
      _isSuccess = true;
      _statusMessage = 'Attendance marked successfully';
     
    });
  } catch (e) {
    print('Firebase error: $e');
    setState(() {
      _isSuccess = false;
      _statusMessage = e.toString();
    });
    rethrow;
  }
}

  Future<void> _processScannedCode(String? rawValue) async {
    if (rawValue == null || rawValue.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final decodedBytes = base64.decode(rawValue);
      final decodedString = utf8.decode(decodedBytes);
      final decodedData = jsonDecode(decodedString) as Map<String, dynamic>;

      _validateRequiredFields(decodedData);

      final String participantEmail = decodedData['participant_email'];
      final String participantId = decodedData['participant_id'];
      final String participantName = decodedData['participant_name'];
      final String eventName=decodedData['event_name'];


      final participantDocRef=_firestore
        .collection('events')
        .doc(eventName)
        .collection('participants')
        .doc(participantId);

      final participantDocSnapshot= await participantDocRef.get();

      if (participantDocSnapshot.exists &&
        participantDocSnapshot.data()?['attendance_status'] == true) {
      if (!mounted) return; //
      showDialog( //
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row( //
              children: [
                Icon(Icons.warning, color: Colors.orange), //
                SizedBox(width: 10), //
                Text('Already Marked'), // Modified title
              ],
            ),
            content: Text( //
                "Participant $participantName ($participantId) is already marked present for event $eventName."), // More specific message
            actions: <Widget>[
              TextButton( //
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop(); //
                  setState(() { //
                    _isProcessing = false;
                  });
                },
              ),
            ],
          );
        },
      );
      return; 
    }

      //confirmationdialogebox

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 10),
                Text('Confirm Attendance'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: Text(decodedData['participant_name']),
                  subtitle: const Text('Participant Name'),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.confirmation_number, color: Colors.blue),
                  title: Text(participantId),
                  subtitle: const Text('Participant ID'),
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.blue),
                  title: Text(participantEmail),
                  subtitle: const Text('Email'),
                ),
                ListTile(
                  leading: const Icon(Icons.event, color: Colors.blue),
                  title: Text(decodedData['event_name']),
                  subtitle: const Text('Event'),
                ),
                if (decodedData['department'] != null)
                  ListTile(
                    leading: const Icon(Icons.business, color: Colors.blue),
                    title: Text(decodedData['department']),
                    subtitle: const Text('Department'),
                  ),
                if (decodedData['role'] != null)
                  ListTile(
                    leading: const Icon(Icons.work, color: Colors.blue),
                    title: Text(decodedData['role']),
                    subtitle: const Text('Role'),
                  ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isProcessing = false;
                  });
                },
              ),
              TextButton(
                child: const Text('Confirm'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _sendDataAndShowResult(decodedData);
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error processing QR: $e');
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 10),
                Text('Error'),
              ],
            ),
            content: Text('Error processing QR code: $e'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isProcessing = false;
                  });
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _sendDataAndShowResult(Map<String, dynamic> decodedData) async {
    try {
      await _updateFirebaseAttendance(decodedData);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  _isSuccess ? Icons.check_circle : Icons.cancel,
                  color: _isSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 10),
                Text(_isSuccess ? 'Attendance Marked' : 'Failed'),
              ],
            ),
            content: Text(_isSuccess
                ? 'Successfully marked attendance for ${decodedData['participant_name']}'
                : 'Failed to mark attendance: $_statusMessage'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isProcessing = false;
                  });
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 10),
                Text('Firebase Error'),
              ],
            ),
            content: Text('Failed to update attendance: $e'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isProcessing = false;
                  });
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: MobileScannerController(
                detectionSpeed: DetectionSpeed.normal,
                facing: CameraFacing.back,
                
              ),
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && !_isProcessing) {
                  
                  
                  _processScannedCode(barcodes.first.rawValue);
                  
                }
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Position QR code in the camera view',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
} 