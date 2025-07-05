import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LibraryScreen extends StatefulWidget {
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Map<String, String>> plants = [];
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  String _keyword = '';
  final TextEditingController _searchController = TextEditingController();
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
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
        'https://chillguys.fun/plant/list?sort=plantName:asc&page=$_currentPage&size=$_pageSize&keyword=${Uri.encodeComponent(_keyword)}',
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
        final List newPlants = data['plants'];
        setState(() {
          plants.addAll(newPlants.map<Map<String, String>>((p) => {
            'id': p['id'].toString(),
            'name': p['plantName'].toString(),
            'image': p['image']?.toString() ?? 'assets/placeholder.png',
          }));
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
            child: GridView.builder(
              controller: _scrollController,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              itemCount: plants.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < plants.length) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlantDetailScreen(
                            plantId: int.parse(plants[index]['id']!),
                            plantName: plants[index]['name']!,
                          ),
                        ),
                      );
                    },
                    child: PlantLibraryItem(plant: plants[index]),
                  );
                } else {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PlantLibraryItem extends StatelessWidget {
  final Map<String, String> plant;
  const PlantLibraryItem({required this.plant});

  @override
  Widget build(BuildContext context) {
    final imageUrl = plant['image'] ?? 'assets/placeholder.png';
    final isNetwork = imageUrl.startsWith('http');
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
              child: isNetwork
                  ? ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              )
                  : Icon(Icons.image, size: 50, color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                plant['name']!,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Plant detail screen - improved UI
class PlantDetailScreen extends StatefulWidget {
  final int plantId;
  final String plantName;

  const PlantDetailScreen({required this.plantId, required this.plantName});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  Map<String, dynamic>? plantData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchPlantDetail();
  }

  Future<void> fetchPlantDetail() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final url = Uri.parse('https://chillguys.fun/plant/detail/${widget.plantId}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          plantData = jsonDecode(response.body)['data'];
        });
      }
    } catch (e) {
      // handle error
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF388e3c)),
      ),
    );
  }

  Widget _buildInfoTable(List tableData) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: List.generate(
            tableData.length,
                (i) {
              final item = tableData[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['attribute']}: ',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                    Expanded(
                      child: Text('${item['value']}',
                          style: const TextStyle(color: Colors.black87)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCareGuide(List careData) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: List.generate(
            careData.length,
                (i) {
              final item = careData[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['attribute']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text('${item['value']}',
                        style: const TextStyle(color: Colors.black87)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plantName),
        centerTitle: true,
        backgroundColor: const Color(0xFF388e3c),
        elevation: 2,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : plantData == null
          ? const Center(child: Text('Failed to load plant info'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plantData!['imageSource'] != null)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    plantData!['imageSource'],
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            if (plantData!['introduction'] != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    plantData!['introduction'],
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
              ),
            if (plantData!['tableData'] != null) ...[
              _buildSectionTitle('Information'),
              _buildInfoTable(plantData!['tableData']),
            ],
            if (plantData!['careData'] != null) ...[
              _buildSectionTitle('Care Guide'),
              _buildCareGuide(plantData!['careData']),
            ],
          ],
        ),
      ),
    );
  }
}