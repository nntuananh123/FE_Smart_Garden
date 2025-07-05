import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../models/garden.dart';
import '../models/user_info.dart';
import '../models/api_error.dart';
import 'area.dart';
import 'profile.dart';
import 'library.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({this.initialTab = 0, Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  bool _isReordering = false;
  List<Map<String, String>> plants = [];
  late List<Map<String, String>> _originalPlants;

  int _currentPage = 1;
  final int _pageSize = 6;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  UserInfo? _userInfo;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _fetchGardens();
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
        _hasMore &&
        _selectedIndex == 0) {
      _fetchGardens();
    }
  }

  Future<void> _fetchGardens() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await AuthService(baseUrl: 'https://chillguys.fun')
          .getGardenList(page: _currentPage, size: _pageSize);
      final newPlants = response.gardens
          .map((g) => {
        'id': g.id.toString(),
        'name': g.gardenName,
        'image': 'https://img.icons8.com/fluency/96/000000/plant-under-sun.png',
      })
          .toList();
      setState(() {
        plants.addAll(newPlants);
        _currentPage++;
        _hasMore = plants.length < response.totalElements;
      });
    } catch (e) {
      // Optionally handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.swap_vert, color: Color(0xFF388e3c)),
                title: Text("Move", style: TextStyle(fontFamily: 'Montserrat')),
                onTap: () {
                  Navigator.pop(context);
                  _startReordering();
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: Color(0xFF388e3c)),
                title: Text("Rename", style: TextStyle(fontFamily: 'Montserrat')),
                onTap: () {
                  Navigator.pop(context);
                  _renamePlant(index);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text("Delete", style: TextStyle(fontFamily: 'Montserrat')),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePlant(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeletePlant(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text("Delete Garden", style: TextStyle(fontFamily: 'Montserrat')),
          content: Text(
            "Are you sure you want to delete this garden? This action cannot be undone.",
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: TextStyle(fontFamily: 'Montserrat')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deletePlant(index);
              },
              child: Text("OK", style: TextStyle(fontFamily: 'Montserrat', color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _startReordering() {
    setState(() {
      _originalPlants = List.from(plants);
      _isReordering = true;
    });
  }

  void _cancelReordering() {
    setState(() {
      plants = List.from(_originalPlants);
      _isReordering = false;
    });
  }

  void _acceptReordering() {
    setState(() {
      _isReordering = false;
    });
  }

  Future<void> _deletePlant(int index) async {
    try {
      final gardenIdStr = plants[index]['id'];
      if (gardenIdStr == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Garden ID not found.")),
        );
        return;
      }
      final gardenId = int.parse(gardenIdStr);

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final url = Uri.parse('https://chillguys.fun/garden/del/$gardenId');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Garden deleted successfully.")),
        );
        setState(() {
          plants.clear();
          _currentPage = 1;
          _hasMore = true;
        });
        _fetchGardens();
      } else {
        final body = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? "Failed to delete garden.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  void _renamePlant(int index) {
    final TextEditingController nameController = TextEditingController(text: plants[index]['name']);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text("Rename Garden", style: TextStyle(fontFamily: 'Montserrat')),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: "New name"),
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: TextStyle(fontFamily: 'Montserrat')),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Please enter a new name.")),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: Text("Confirm Rename", style: TextStyle(fontFamily: 'Montserrat')),
                    content: Text("Are you sure you want to rename this garden to \"$newName\"?", style: TextStyle(fontFamily: 'Montserrat')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text("Cancel", style: TextStyle(fontFamily: 'Montserrat')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text("OK", style: TextStyle(fontFamily: 'Montserrat', color: Colors.green)),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  final gardenId = int.parse(plants[index]['id']!);
                  final prefs = await SharedPreferences.getInstance();
                  final accessToken = prefs.getString('accessToken');
                  final url = Uri.parse('https://chillguys.fun/garden/upd');
                  final response = await http.put(
                    url,
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $accessToken',
                    },
                    body: jsonEncode({
                      'id': gardenId,
                      'gardenName': newName,
                    }),
                  );
                  final body = jsonDecode(response.body);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(body['message'] ?? "Rename result unknown.")),
                  );
                  if (response.statusCode == 200) {
                    setState(() {
                      plants.clear();
                      _currentPage = 1;
                      _hasMore = true;
                    });
                    _fetchGardens();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              },
              child: Text("Save", style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF388e3c))),
            ),
          ],
        );
      },
    );
  }

  void _addPlant() {
    TextEditingController bs = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text("Add new Garden", style: TextStyle(fontFamily: 'Montserrat')),
          content: TextField(
            controller: bs,
            decoration: InputDecoration(labelText: "Name"),
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: TextStyle(fontFamily: 'Montserrat')),
            ),
            TextButton(
              onPressed: () async {
                final name = bs.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Please enter a garden name.")),
                  );
                  return;
                }
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final accessToken = prefs.getString('accessToken');
                  if (accessToken == null) throw Exception("No access token found");

                  final userInfo = await AuthService(baseUrl: 'https://chillguys.fun').getMyInfo();
                  final userId = userInfo.id;

                  final url = Uri.parse('https://chillguys.fun/garden/add');
                  final response = await http.post(
                    url,
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $accessToken',
                    },
                    body: jsonEncode({
                      'gardenName': name,
                      'userId': userId,
                    }),
                  );
                  final body = jsonDecode(response.body);
                  if (response.statusCode == 200) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(body['message'] ?? "Garden added successfully.")),
                    );
                    Navigator.pop(dialogContext);
                    setState(() {
                      plants.clear();
                      _currentPage = 1;
                      _hasMore = true;
                    });
                    _fetchGardens();
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(body['message'] ?? "Failed to add garden.")),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              },
              child: Text("Add", style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF388e3c))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _selectedIndex == 0
              ? "My Garden"
              : _selectedIndex == 1
              ? "Library"
              : "Profile",
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
        automaticallyImplyLeading: false,
        actions: _selectedIndex == 0
            ? [
          IconButton(
            icon: Icon(Icons.add, color: Colors.black),
            onPressed: _addPlant,
            tooltip: "Add Garden",
          ),
          if (_isReordering) ...[
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.black),
              onPressed: _cancelReordering,
              tooltip: "Cancel",
            ),
            IconButton(
              icon: Icon(Icons.check, color: Colors.black),
              onPressed: _acceptReordering,
              tooltip: "Save Order",
            ),
          ]
        ]
            : [],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFFe8f5e9), // Light green base color
        ),
        child: Stack(
          children: [
            // Cartoon-style garden background with patterns
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
              painter: GardenBackgroundPainter(),
            ),
            // Content
            SafeArea(
              child: _selectedIndex == 0
                  ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isReordering
                    ? buildReorderableGrid()
                    : buildNormalGrid(),
              )
                  : _selectedIndex == 1
                  ? LibraryScreen()
                  : ProfileScreenWithBackground(),
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

  Widget buildReorderableGrid() {
    return ReorderableGridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.9,
      ),
      itemCount: plants.length,
      dragEnabled: true,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) newIndex--;
          final item = plants.removeAt(oldIndex);
          plants.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        return Material(
          key: ValueKey(plants[index]),
          color: Colors.transparent,
          child: PlantItem(plant: plants[index]),
        );
      },
    );
  }

  Widget buildNormalGrid() {
    return Column(
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
            itemCount: plants.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < plants.length) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AreaScreen(
                          gardenName: plants[index]['name'],
                          gardenId: plants[index]['id'],
                        ),
                      ),
                    );
                  },
                  onLongPress: () => _showOptions(index),
                  child: PlantItem(plant: plants[index]),
                );
              } else {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class PlantItem extends StatelessWidget {
  final Map<String, String> plant;
  const PlantItem({required this.plant});

  @override
  Widget build(BuildContext context) {
    final imageUrl = plant['image'] ?? '';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 5),
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
                color: Color(0xFFe8f5e9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: 80,
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
                plant['name']!,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                  color: Color(0xFF2e7d32),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Updated ProfileScreenWithBackground with the new garden theme
class ProfileScreenWithBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Custom painted background that matches the home screen
        Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: CustomPaint(
            painter: GardenBackgroundPainter(),
          ),
        ),
        // Profile content
        ProfileScreen(),
      ],
    );
  }
}

class GardenBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Sky
    Paint skyPaint = Paint()..color = Color(0xFFc6e8ff);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Sun
    Paint sunPaint = Paint()..color = Color(0xFFfdd835);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 40, sunPaint);

    // Clouds
    Paint cloudPaint = Paint()..color = Colors.white.withOpacity(0.8);
    // Cloud 1
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.12), 30, cloudPaint);
    canvas.drawCircle(Offset(size.width * 0.28, size.height * 0.1), 35, cloudPaint);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.13), 28, cloudPaint);

    // Cloud 2
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.22), 25, cloudPaint);
    canvas.drawCircle(Offset(size.width * 0.67, size.height * 0.2), 30, cloudPaint);
    canvas.drawCircle(Offset(size.width * 0.73, size.height * 0.23), 22, cloudPaint);

    // Ground
    Paint grassPaint = Paint()..color = Color(0xFF81c784);
    Path grassPath = Path()
      ..moveTo(0, size.height * 0.75)
      ..lineTo(size.width, size.height * 0.75)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(grassPath, grassPaint);

    // Small hills
    Paint hillPaint = Paint()..color = Color(0xFF66bb6a);
    Path hillPath = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.65, size.width * 0.5, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.65, size.width, size.height * 0.75)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    // Trees
    _drawCartoonTree(canvas, Offset(size.width * 0.15, size.height * 0.75), 40);
    _drawCartoonTree(canvas, Offset(size.width * 0.85, size.height * 0.75), 50);

    // Flowers
    for (int i = 0; i < 8; i++) {
      double x = size.width * (0.1 + 0.1 * i);
      double y = size.height * 0.75 + 15;
      _drawCartoonFlower(canvas, Offset(x, y));
    }
  }

  void _drawCartoonTree(Canvas canvas, Offset position, double size) {
    // Tree trunk
    Paint trunkPaint = Paint()..color = Color(0xFF8d6e63);
    canvas.drawRect(
        Rect.fromLTWH(position.dx - size/8, position.dy - size/2, size/4, size/2),
        trunkPaint
    );

    // Tree crown
    Paint leafPaint = Paint()..color = Color(0xFF43a047);
    canvas.drawCircle(Offset(position.dx, position.dy - size/2 - size/3), size/2, leafPaint);
  }

  void _drawCartoonFlower(Canvas canvas, Offset position) {
    // Stem
    Paint stemPaint = Paint()
      ..color = Color(0xFF7cb342)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        position,
        Offset(position.dx, position.dy - 15),
        stemPaint
    );

    // Flower petals
    List<Color> flowerColors = [
      Color(0xFFf06292), // pink
      Color(0xFFffee58), // yellow
      Color(0xFF9575cd), // purple
      Color(0xFF4fc3f7), // blue
    ];

    Color flowerColor = flowerColors[position.dx.toInt() % flowerColors.length];
    Paint flowerPaint = Paint()..color = flowerColor;

    canvas.drawCircle(Offset(position.dx, position.dy - 20), 6, flowerPaint);
    canvas.drawCircle(Offset(position.dx + 5, position.dy - 15), 6, flowerPaint);
    canvas.drawCircle(Offset(position.dx - 5, position.dy - 15), 6, flowerPaint);
    canvas.drawCircle(Offset(position.dx, position.dy - 10), 6, flowerPaint);

    // Flower center
    Paint centerPaint = Paint()..color = Color(0xFFffd54f);
    canvas.drawCircle(Offset(position.dx, position.dy - 15), 4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}