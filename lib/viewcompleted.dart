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
    this.listHeight = 250.0, // Adjusted height for the list card
  });

  @override
  _ViewCompletedPageState createState() => _ViewCompletedPageState();
}

class _ViewCompletedPageState extends State<ViewCompletedPage> {
  bool _isTileView = true;
  List<DocumentSnapshot> completedDocs = [];
  String _filter = 'all';
  String _searchQuery = '';

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

  void _setSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _clearSearchQuery() {
    setState(() {
      _searchQuery = '';
    });
  }

  void _clearFilter() {
    setState(() {
      _filter = 'all';
    });
  }

  List<DocumentSnapshot> get filteredDocs {
    if (_filter == 'all' && _searchQuery.isEmpty) return completedDocs;

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
          default:
            return true;
        }
      }();

      final matchesSearch = _searchQuery.isEmpty || data['address'].toString().toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesDate && matchesSearch;
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
                title: Text('All'),
                onTap: () {
                  _setFilter('all');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _showAddressDialog() async {
    TextEditingController _controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Address'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: 'Address'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(_controller.text);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
    return _controller.text;
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
        width: 320,  // Longer width for title card
        height: 200,  // Custom height for list card
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
                      ),
                    );
                  }
                  return Text(
                    'Completed by: ${snapshot.data}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  );
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
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () async {
              String query = await _showAddressDialog();
              _setSearchQuery(query);
            },
          ),
        ],
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
                    if (_searchQuery.isNotEmpty)
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
                              _searchQuery.length > 10 ? '${_searchQuery.substring(0, 10)}...' : _searchQuery,
                              style: TextStyle(color: Colors.black, fontSize: 16.0),
                            ),
                            SizedBox(width: 8.0),
                            GestureDetector(
                              onTap: _clearSearchQuery,
                              child: Icon(Icons.close, color: Colors.red, size: 18.0),
                            ),
                          ],
                        ),
                      ),
                    if (_filter != 'all')
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
                              _filter,
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
              Row(
                children: [
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
            ],
          ),
          Expanded(
            child: _isTileView
                ? GridView.builder(
                    padding: EdgeInsets.all(8.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.65),
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
