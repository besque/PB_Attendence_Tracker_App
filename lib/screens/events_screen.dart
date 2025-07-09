import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _showAllEvents = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showAllEvents ? 'All Events' : 'Recent Event'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('events').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No events found'),
            );
          }

          final documents = snapshot.data!.docs;
          
          // Sort by latest check-in activity 
          documents.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final String? aLatestTime = aData['latest_checkin_activity'] as String?;
            final String? bLatestTime = bData['latest_checkin_activity'] as String?;

            if (aLatestTime == null && bLatestTime == null) return 0;
            if (aLatestTime == null) return 1;
            if (bLatestTime == null) return -1;
            return bLatestTime.compareTo(aLatestTime); // Descending order
          });

          // show recent events or all based on state
          final displayDocuments =
              _showAllEvents ? documents : documents.take(1).toList();

          return ListView.builder(
            itemCount: displayDocuments.length,
            itemBuilder: (context, index) {
              final eventDoc = displayDocuments[index];
              final eventData = eventDoc.data() as Map<String, dynamic>;
              final eventName = eventData['event_name'] ?? eventDoc.id;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ExpansionTile(
                  title: Text(
                    eventName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('events')
                        .doc(eventDoc.id)
                        .collection('participants')
                        .get(),
                    builder: (context, participantsSnapshot) {
                      if (participantsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Text('Loading participants...');
                      }
                      
                      final participantCount = participantsSnapshot.data?.docs.length ?? 0;
                      final latestActivity = eventData['latest_checkin_activity'];
                      
                      return Text(
                        '$participantCount Participants${latestActivity != null ? ' · Last activity: ${_formatCheckInTime(latestActivity)}' : ''}',
                        style: const TextStyle(color: Colors.grey),
                      );
                    },
                  ),
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('events')
                          .doc(eventDoc.id)
                          .collection('participants')
                          .snapshots(),
                      builder: (context, participantsSnapshot) {
                        if (participantsSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (!participantsSnapshot.hasData || 
                            participantsSnapshot.data!.docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: Text('No participants found')),
                          );
                        }

                        final participants = participantsSnapshot.data!.docs;

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: participants.length,
                          itemBuilder: (context, index) {
                            final participantDoc = participants[index];
                            final participantData = participantDoc.data() as Map<String, dynamic>;
                            
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(
                                participantData['participant_name'] ?? 'Unknown',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    participantData['participant_email'] ?? 'No email',
                                  ),
                                  Text(
                                    'ID: ${participantData['participant_id'] ?? participantDoc.id}',
                                  ),
                                  if (participantData['department'] != null)
                                    Text(
                                      'Department: ${participantData['department']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: participantData['check_in_time'] != null
                                  ? Text(
                                      _formatCheckInTime(participantData['check_in_time']),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    )
                                  : const Text(
                                      '-:-',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                      ),
                                    ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _showAllEvents = !_showAllEvents;
          });
        },
        icon: Icon(_showAllEvents ? Icons.history : Icons.history_toggle_off),
        label: Text(_showAllEvents ? 'Show Recent Only' : 'View Past Events'),
      ),
    );
  }

  String _formatCheckInTime(String? isoString) {
    if (isoString == null) return 'No time';
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();

      // show date if not today
      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        return '${dateTime.hour.toString().padLeft(2, '0')}:'
            '${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.day}/${dateTime.month} '
            '${dateTime.hour.toString().padLeft(2, '0')}:'
            '${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return 'Invalid time';
    }
  }
}