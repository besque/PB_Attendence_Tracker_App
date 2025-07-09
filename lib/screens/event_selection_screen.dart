// event_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'participant_selection_screen.dart';

class EventSelectionScreen extends StatefulWidget {
  final String subject;
  final String body;
  final bool includeQR;

  const EventSelectionScreen({
    super.key,
    required this.subject,
    required this.body,
    required this.includeQR,
  });

  @override
  State<EventSelectionScreen> createState() => _EventSelectionScreenState();
}

class _EventSelectionScreenState extends State<EventSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select an Event'),
      ),
      
      body: StreamBuilder<QuerySnapshot>(
        
        stream: FirebaseFirestore.instance.collection('events').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No events found.'));
          }

         
          final eventDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: eventDocs.length,
            itemBuilder: (context, index) {
              final event = eventDocs[index];
              
              final eventName = event.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(eventName),
                  leading: const Icon(Icons.event_note),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                   
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParticipantSelectionScreen(
                          subject: widget.subject,
                          body: widget.body,
                          includeQR: widget.includeQR,
                          eventName: eventName, 
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
}