import 'package:flutter/material.dart';
import '../models/participant_model.dart';
import '../services/mailing_service.dart';
import '../widgets/participant_search_bar.dart';
import '../widgets/participant_sort_controls.dart';

enum ParticipantSortOption {
  name,
  teamId,
  affiliation,
  affiliationType,
  experienceLevel,
  previousParticipation,
  age
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
  State<ParticipantSelectionScreen> createState() =>
      _ParticipantSelectionScreenState();
}

class _ParticipantSelectionScreenState
    extends State<ParticipantSelectionScreen> {
  final MailingService _mailingService = MailingService();


  List<ParticipantModel> _originalParticipants = [];
  List<ParticipantModel> _displayParticipants = [];

  final TextEditingController _searchController = TextEditingController();
  ParticipantSortOption _sortOption = ParticipantSortOption.name;
  bool _isLoading = true;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
    _searchController.addListener(_applyFiltersAndSort);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<void> _fetchParticipants() async {
    try {
      final participants =
          await _mailingService.fetchParticipants(widget.eventName);
      if (!mounted) return;
      setState(() {
        _originalParticipants = participants;
        _applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  void _applyFiltersAndSort() {
    List<ParticipantModel> tempParticipants = List.from(_originalParticipants);
    final query = _searchController.text.toLowerCase();

    if (query.isNotEmpty) {
      tempParticipants = tempParticipants.where((p) {
        final nameLower = p.name.toLowerCase();
        final emailLower = p.email.toLowerCase();
        final affiliationLower = p.affiliationName?.toLowerCase() ?? '';
        return nameLower.contains(query) ||
               emailLower.contains(query) ||
               affiliationLower.contains(query);
      }).toList();
    }

    switch (_sortOption) {
      case ParticipantSortOption.name:
        tempParticipants.sort((a, b) => a.name.compareTo(b.name));
        break;
      case ParticipantSortOption.teamId:
        tempParticipants.sort((a, b) => a.teamId.compareTo(b.teamId));
        break;
      case ParticipantSortOption.affiliation:
        tempParticipants.sort((a, b) => (a.affiliationName ?? '').compareTo(b.affiliationName ?? ''));
        break;
      case ParticipantSortOption.affiliationType:
        tempParticipants.sort((a, b) => (a.affiliationType ?? '').compareTo(b.affiliationType ?? ''));
        break;
      case ParticipantSortOption.experienceLevel:
        tempParticipants.sort((a, b) => (a.experienceLevel ?? '').compareTo(b.experienceLevel ?? ''));
        break;
      case ParticipantSortOption.previousParticipation:
        tempParticipants.sort((a, b) => (b.previousParticipation ?? false) ? 1 : -1);
        break;
      case ParticipantSortOption.age:
        tempParticipants.sort((a, b) => (a.age ?? 999).compareTo(b.age ?? 999));
        break;
    }

    setState(() {
      _displayParticipants = tempParticipants;
    });
  }

  Future<void> _sendEmails() async {
    final selectedParticipants = _originalParticipants
        .where((p) => p.isSelected)
        .map((p) => p.toJson())
        .toList();

    if (selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one participant')),
      );
      return;
    }

    _showSendingDialog();

    try {
      final responseData = await _mailingService.sendEmails(
        subject: widget.subject,
        body: widget.body,
        includeQR: widget.includeQR,
        participants: selectedParticipants,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // Close the sending dialog
      _showResultDialog(responseData['success'] ?? false,
          responseData['message'] ?? 'An unknown error occurred.');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close the sending dialog
      _showResultDialog(false, e.toString());
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
                child: const Text('OK'), onPressed: () => Navigator.of(c).pop())
          ]),
    );
  }

  Widget _buildSortContextRow(ParticipantModel participant) {
    String? contextText;
    switch (_sortOption) {
      case ParticipantSortOption.affiliation:
        contextText = 'Affiliation: ${participant.affiliationName ?? 'N/A'}';
        break;
      case ParticipantSortOption.affiliationType:
        contextText = 'Type: ${participant.affiliationType ?? 'N/A'}';
        break;
      case ParticipantSortOption.experienceLevel:
        contextText = 'Experience: ${participant.experienceLevel ?? 'N/A'}';
        break;
      case ParticipantSortOption.previousParticipation:
        contextText = 'Participated Before: ${participant.previousParticipation == true ? "Yes" : "No"}';
        break;
      case ParticipantSortOption.age:
        contextText = 'Age: ${participant.age?.toString() ?? 'N/A'}';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Text(
      contextText,
      style: const TextStyle(fontSize: 12, color: Colors.deepPurple, fontStyle: FontStyle.italic),
    );
  }



  void _showSendingDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const AlertDialog(
                content: Row(children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Sending...")
            ])));
  }

  void _showResultDialog(bool success, String message) {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(success ? "Success" : "Error"),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(c).pop(); // Close result dialog
                        if (success)
                          Navigator.of(context).pop(); // Go back if successful
                      },
                      child: const Text("OK"))
                ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Recipients for ${widget.eventName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ParticipantSearchBar(controller: _searchController),
                ParticipantSortControls(
                  currentSortOption: _sortOption,
                  onSortOptionChanged: (newOption) {
                    setState(() {
                      _sortOption = newOption;
                      _applyFiltersAndSort();
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text("Select All"),
                  value: _selectAll,
                  onChanged: (bool? value) {
                    setState(() {
                      _selectAll = value ?? false;
                      for (var p in _displayParticipants) {
                        p.isSelected = _selectAll;
                      }
                    });
                  },
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _displayParticipants.length,
                    itemBuilder: (context, index) {
                      final participant = _displayParticipants[index];
                      return CheckboxListTile(
                        isThreeLine: true,
                        title: Text(participant.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text(participant.email),
                            Text(
                              'Team: ${participant.teamId}',
                              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                            ),
                            _buildSortContextRow(participant),
                          ],
                        ),
                        value: participant.isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            participant.isSelected = value ?? false;
                            _selectAll =
                                _displayParticipants.every((p) => p.isSelected);
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
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50)),
                  ),
                ),
              ],
            ),
    );
  }
}
