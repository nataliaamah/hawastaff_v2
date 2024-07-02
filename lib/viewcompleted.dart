import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'emergencyview.dart';

class ViewCompletedPage extends StatefulWidget {
  final String userId;
  final String fullName;
  final double titleSize;
  final double listHeight;

  ViewCompletedPage({
    required this.userId,
    required this.fullName,
    this.titleSize = 20.0,
    this.listHeight = 250.0,
  });

  @override
  _ViewCompletedPageState createState() => _ViewCompletedPageState();
}

class _ViewCompletedPageState extends State<ViewCompletedPage> {
  bool _isTileView = true;
  List<DocumentSnapshot> completedDocs = [];
  String _filter = 'all';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchCompletedDocs();
  }

  void _fetchCompletedDocs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('staff_emergency')
          .where('status', isEqualTo: 'completed')
          .get();
      setState(() {
        completedDocs = snapshot.docs;
        completedDocs.sort((a, b) {
          final timestampA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
          final timestampB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
          return timestampB.compareTo(timestampA);
        });
      });
    } catch (e) {
      print('Error fetching completed emergencies: $e');
    }
  }

  void _toggleView() {
    setState(() {
      _isTileView = !_isTileView;
    });
  }

  void _setFilter(String filter) {
    setState(() {
      _filter = filter;
    });
  }

  void _clearFilter() {
    setState(() {
      _filter = 'all';
      _selectedDate = null;
    });
  }

  List<DocumentSnapshot> get filteredDocs {
    if (_filter == 'all' && _selectedDate == null) return completedDocs;

    final now = DateTime.now();
    final filtered = completedDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp;
      final date = timestamp.toDate();

      final matchesDate = () {
        switch (_filter) {
          case 'day':
            return date.day == now.day && date.month == now.month && date.year == now.year;
          case 'week':
            return now.difference(date).inDays <= 7;
          case 'month':
            return date.month == now.month && date.year == now.year;
          case 'specific':
            return _selectedDate != null && date.day == _selectedDate!.day && date.month == _selectedDate!.month && date.year == _selectedDate!.year;
          default:
            return true;
        }
      }();

      return matchesDate;
    }).toList();

    return filtered;
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Filter'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Day'),
                onTap: () {
                  _setFilter('day');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Week'),
                onTap: () {
                  _setFilter('week');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Month'),
                onTap: () {
                  _setFilter('month');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('Specific Date'),
                onTap: () async {
                  DateTime? pickedDate = await _selectDate(context);
                  if (pickedDate != null) {
                    setState(() {
                      _selectedDate = pickedDate;
                      _filter = 'specific';
                    });
                  }
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('All'),
                onTap: () {
                  _clearFilter();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<DateTime?> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    return picked;
  }

  Widget _buildEmergencyCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffEmergencyViewPage(emergencyData: doc),
          ),
        );
      },
      child: Container(
        width: 320,
        height: widget.listHeight,
        margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isTileView) ...[
                Text(
                  _formatDate(data['timestamp']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                Text(
                  _formatTime(data['timestamp']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
              ],
              SizedBox(height: 8),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(data['userId']).get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                    return Text(
                      'Unknown User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    );
                  }
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  return Text(
                    userData['fullName'] ?? 'Unknown User',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  );
                },
              ),
              SizedBox(height: 4),
              FutureBuilder<String>(
                future: _convertGeoPointToAddress(data['location']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text(
                      'Fetching location...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Unknown location',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    );
                  }
                  return Text(
                    snapshot.data ?? 'Unknown location',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              SizedBox(height: 20),
              FutureBuilder<String>(
                future: data['completedBy'] != null ? _getStaffDetails(data['completedBy']) : Future.value('Unknown Staff'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Completed by: Unknown Staff',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }
                  if (_isTileView) {
                    return Text(
                      'Completed by: ${snapshot.data}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  } else {
                    return Text(
                      'Completed: ${_formatTime(data['completedAt'])} ${_formatDate(data['completedAt'])} by ${snapshot.data}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Unknown Date';
    }
    final date = timestamp.toDate();
    return DateFormat('d/MM/yyyy').format(date);
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Unknown Time';
    }
    final date = timestamp.toDate();
    return DateFormat('h:mm a').format(date);
  }

  Future<String> _convertGeoPointToAddress(GeoPoint geoPoint) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(geoPoint.latitude, geoPoint.longitude);
      Placemark place = placemarks[0];
      return '${place.street}, ${place.locality}, ${place.country}';
    } catch (e) {
      print('Error occurred while converting geopoint to address: $e');
      return 'Unknown location';
    }
  }

  Future<String> _getStaffDetails(String staffId) async {
    try {
      final staffSnapshot = await FirebaseFirestore.instance.collection('staff').doc(staffId).get();
      if (staffSnapshot.exists) {
        final staffData = staffSnapshot.data() as Map<String, dynamic>;
        return '${staffData['name']} (Code: ${staffData['staffNumber']}, Position: ${staffData['position']})';
      }
      return 'Unknown Staff';
    } catch (e) {
      print('Error fetching staff details: $e');
      return 'Unknown Staff';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(2, 1, 34, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(2, 1, 34, 1),
        leading: BackButton(color: Colors.white),
        title: Text(
          'Completed',
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.titleSize,
          ),
        ),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8.0,
                  children: [
                    if (_selectedDate != null)
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('d/MM/yyyy').format(_selectedDate!),
                              style: TextStyle(color: Colors.black, fontSize: 16.0),
                            ),
                            SizedBox(width: 8.0),
                            GestureDetector(
                              onTap: _clearFilter,
                              child: Icon(Icons.close, color: Colors.red, size: 18.0),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.filter_list, color: Colors.white),
                onPressed: _showFilterDialog,
              ),
              IconButton(
                icon: Icon(_isTileView ? Icons.view_list : Icons.view_module, color: Colors.white),
                onPressed: _toggleView,
              ),
            ],
          ),
          Expanded(
            child: _isTileView
                ? GridView.builder(
                    padding: EdgeInsets.all(8.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.5),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      return _buildEmergencyCard(filteredDocs[index]);
                    },
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(8.0),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      return _buildEmergencyCard(filteredDocs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
