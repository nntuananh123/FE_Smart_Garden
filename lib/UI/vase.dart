import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'vase_detail.dart';
import 'home.dart';
import 'library.dart';
import 'profile.dart';

class Vase {
  final int id;
  final String vaseName;
  final int areaId;
  final String areaName;
  final int plantId;
  final String plantName;
  final String? image;
  final int deviceId;

  Vase({
    required this.id,
    required this.vaseName,
    required this.areaId,
    required this.areaName,
    required this.plantId,
    required this.plantName,
    this.image,
    required this.deviceId,
  });

  Vase copyWith({String? image}) {
    return Vase(
      id: id,
      vaseName: vaseName,
      areaId: areaId,
      areaName: areaName,
      plantId: plantId,
      plantName: plantName,
      image: image ?? this.image,
      deviceId: deviceId,
    );
  }

  factory Vase.fromJson(Map<String, dynamic> json) {
    return Vase(
      id: json['id'],
      vaseName: json['vaseName'],
      areaId: json['area']['id'],
      areaName: json['area']['areaName'],
      plantId: json['plant']['id'],
      plantName: json['plant']['plantName'],
      image: json['plant']?['image'],
      deviceId: json['deviceId'],
    );
  }
}

class VaseScreen extends StatefulWidget {
  final String? areaName;
  final String? areaId;

  const VaseScreen({required this.areaName, required this.areaId});

  @override
  _VaseScreenState createState() => _VaseScreenState();
}

class _VaseScreenState extends State<VaseScreen> {
  int _selectedIndex = 0;
  List<Vase> vases = [];
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  // Track used deviceIds
  List<int> usedDeviceIds = [];

  @override
  void initState() {
    super.initState();
    _fetchVases();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchVases();
    }
  }

  void _showVaseOptions(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit),
                title: Text("Rename"),
                onTap: () {
                  Navigator.pop(context);
                  _renameVase(index);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text("Delete"),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteVase(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _renameVase(int index) {
    final vase = vases[index];
    final TextEditingController controller = TextEditingController(text: vase.vaseName);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Rename Vase"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: "New Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Please enter a new name.")),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final accessToken = prefs.getString('accessToken');
                  final url = Uri.parse('https://chillguys.fun/vase/upd');
                  final response = await http.put(
                    url,
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $accessToken',
                    },
                    body: jsonEncode({
                      'id': vase.id,
                      'vaseName': newName,
                      'plantId': vase.plantId,
                      'deviceId': vase.deviceId,
                    }),
                  );
                  final body = jsonDecode(response.body);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(body['message'] ?? "Rename result unknown.")),
                  );
                  if (response.statusCode == 200) {
                    setState(() {
                      vases[index] = Vase(
                        id: vase.id,
                        vaseName: newName,
                        areaId: vase.areaId,
                        areaName: vase.areaName,
                        plantId: vase.plantId,
                        plantName: vase.plantName,
                        image: vase.image,
                        deviceId: vase.deviceId,
                      );
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteVase(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Delete Vase"),
          content: Text("Are you sure you want to delete this vase? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteVase(index);
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteVase(int index) async {
    final vaseId = vases[index].id;
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final url = Uri.parse('https://chillguys.fun/vase/del/$vaseId');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? "Vase deleted successfully.")),
        );
        setState(() {
          vases.removeAt(index);
          _updateUsedDeviceIds();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? "Failed to delete vase.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<String?> _fetchVaseImage(int vaseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final url = Uri.parse('https://chillguys.fun/vase/$vaseId');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        return data['plant']?['image'];
      }
    } catch (e) {}
    return null;
  }

  void _updateUsedDeviceIds() {
    usedDeviceIds = vases.map((v) => v.deviceId).toList();
  }

  Future<void> _fetchVases() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final url = Uri.parse('https://chillguys.fun/vase/list?page=$_currentPage&size=$_pageSize');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final List<Vase> allFetched = (data['vases'] as List)
            .map((e) => Vase.fromJson(e))
            .toList();
        final List<Vase> filtered = allFetched
            .where((v) => v.areaId.toString() == widget.areaId)
            .toList();

        // Fetch images for each vase
        for (var i = 0; i < filtered.length; i++) {
          if (filtered[i].image == null) {
            final img = await _fetchVaseImage(filtered[i].id);
            filtered[i] = filtered[i].copyWith(image: img);
          }
        }

        setState(() {
          vases.addAll(filtered);
          _updateUsedDeviceIds();
          _hasMore = allFetched.length == _pageSize;
          if (_hasMore) _currentPage++;
        });
      }
    } catch (e) {
      // handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(initialTab: 1)));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(initialTab: 2)));
    }
  }

  void _addVase() async {
    // Fetch all vases (not just for this area)
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    final url = Uri.parse('https://chillguys.fun/vase/list?page=1&size=1000'); // Large size to get all
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data']['vases'] as List;
      List<int> used = data.map((e) => e['deviceId'] as int).toList();
      if (used.length >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Maximum number of vases reached (2 in total).")),
        );
        return;
      }
      // Find available deviceId (1 or 2)
      int deviceId = [1, 2].firstWhere((id) => !used.contains(id));
      showDialog(
        context: context,
        builder: (dialogContext) => PlantPickerDialog(
          onPlantSelected: (plant) async {
            try {
              final prefs = await SharedPreferences.getInstance();
              final accessToken = prefs.getString('accessToken');
              final url = Uri.parse('https://chillguys.fun/vase/add');
              final response = await http.post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $accessToken',
                },
                body: jsonEncode({
                  'vaseName': plant['plantName'],
                  'areaId': int.parse(widget.areaId!),
                  'plantId': plant['id'],
                  'deviceId': deviceId,
                }),
              );
              final body = jsonDecode(response.body);
              if (response.statusCode == 200) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(body['message'] ?? "Vase added successfully.")),
                );
                Navigator.pop(dialogContext);
                setState(() {
                  vases.clear();
                  _currentPage = 1;
                  _hasMore = true;
                });
                _fetchVases();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(body['message'] ?? "Failed to add vase.")),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: ${e.toString()}")),
              );
            }
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "${widget.areaName} Vases",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
            color: Colors.black,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                color: Colors.black38,
                offset: Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.black),
            onPressed: _addVase,
            tooltip: "Add Vase",
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFFe8f5e9),
        ),
        child: Stack(
          children: [
            // Garden background
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
              painter: GardenBackgroundPainter(),
            ),
            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        controller: _scrollController,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: vases.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < vases.length) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VaseDetailScreen(
                                      vaseId: vases[index].id,
                                      deviceId: vases[index].deviceId,
                                    ),
                                  ),
                                );
                              },
                              onLongPress: () => _showVaseOptions(index),
                              child: VaseItem(vase: vases[index]),
                            );
                          } else {
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388e3c)),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Color(0xFF094c29),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Library'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          onTap: _onItemTapped,
          selectedLabelStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontFamily: 'Montserrat'),
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}

class VaseItem extends StatelessWidget {
  final Vase vase;
  const VaseItem({required this.vase});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: vase.image != null
                  ? ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  vase.image!,
                  fit: BoxFit.cover,
                  height: 100,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              )
                  : Icon(Icons.image, size: 50, color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                vase.vaseName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Dialog chọn plant với infinite scroll
class PlantPickerDialog extends StatefulWidget {
  final Function(Map<String, dynamic> plant) onPlantSelected;
  const PlantPickerDialog({required this.onPlantSelected});

  @override
  State<PlantPickerDialog> createState() => _PlantPickerDialogState();
}

class _PlantPickerDialogState extends State<PlantPickerDialog> {
  List<Map<String, dynamic>> plants = [];
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  String _keyword = '';
  final TextEditingController _searchController = TextEditingController();
  // Debounce for search
  DateTime? _lastSearchTime;

  @override
  void initState() {
    super.initState();
    _fetchPlants();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 &&
        !_isLoading &&
        _hasMore) {
      _fetchPlants();
    }
  }

  void _onSearchChanged() {
    final now = DateTime.now();
    _lastSearchTime = now;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_lastSearchTime == now) {
        setState(() {
          _keyword = _searchController.text.trim();
          plants.clear();
          _currentPage = 1;
          _hasMore = true;
        });
        _fetchPlants();
      }
    });
  }

  Future<void> _fetchPlants() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final url = Uri.parse(
        'https://chillguys.fun/plant/list?page=$_currentPage&size=$_pageSize&keyword=${Uri.encodeComponent(_keyword)}',
      );
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final List newPlants = data['plants'] ?? [];
        setState(() {
          plants.addAll(newPlants.cast<Map<String, dynamic>>());
          _currentPage++;
          _hasMore = plants.length < data['totalElements'];
        });
      }
    } catch (e) {
      // Optionally handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Select Plant"),
      content: SizedBox(
        width: double.maxFinite,
        height: 480,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search plant...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: plants.isEmpty && _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                controller: _scrollController,
                itemCount: plants.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < plants.length) {
                    final plant = plants[index];
                    return ListTile(
                      leading: plant['image'] != null
                          ? Image.network(
                        plant['image'],
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.broken_image, size: 40, color: Colors.grey),
                      )
                          : Icon(Icons.image, size: 40, color: Colors.grey),
                      title: Text(plant['plantName']),
                      onTap: () => widget.onPlantSelected(plant),
                    );
                  } else {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel"),
        ),
      ],
    );
  }
}