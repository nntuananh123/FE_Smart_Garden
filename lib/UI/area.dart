import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'vase.dart';
import 'home.dart';
import 'library.dart';
import 'profile.dart';

class AreaScreen extends StatefulWidget {
  final String? gardenName;
  final String? gardenId;

  const AreaScreen({required this.gardenName, required this.gardenId});

  @override
  _AreaScreenState createState() => _AreaScreenState();
}

class _AreaScreenState extends State<AreaScreen> {
  int _selectedIndex = 0;
  bool _isReordering = false;
  List<Map<String, String>> areas = [];
  late List<Map<String, String>> _originalAreas;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchAreas();
    _originalAreas = List.from(areas);
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

  Future<void> _fetchAreas() async {
    setState(() {
      _loading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final url = Uri.parse('https://chillguys.fun/area/list');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data']['areas'] as List;
        setState(() {
          areas = data
              .where((a) => a['gardenId'].toString() == widget.gardenId)
              .map<Map<String, String>>((a) => {
            'id': a['id'].toString(),
            'name': a['areaName'].toString(),
            'image': 'assets/placeholder.png',
          })
              .toList();
        });
      }
    } catch (e) {
      // handle error
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _addArea() {
    TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Add new Area"),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: "Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final name = _controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Please enter an area name.")),
                  );
                  return;
                }
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final accessToken = prefs.getString('accessToken');
                  final url = Uri.parse('https://chillguys.fun/area/add');
                  final response = await http.post(
                    url,
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $accessToken',
                    },
                    body: jsonEncode({
                      'areaName': name,
                      'gardenId': int.parse(widget.gardenId!),
                    }),
                  );
                  final body = jsonDecode(response.body);
                  if (response.statusCode == 200) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(body['message'] ?? "Area added successfully.")),
                    );
                    Navigator.pop(dialogContext);
                    _fetchAreas();
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(body['message'] ?? "Failed to add area.")),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              },
              child: Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _showOptions(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.swap_vert),
                title: Text("Move"),
                onTap: () {
                  Navigator.pop(context);
                  _startReordering();
                },
              ),
              ListTile(
                leading: Icon(Icons.edit),
                title: Text("Rename"),
                onTap: () {
                  Navigator.pop(context);
                  _renameArea(index);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text("Delete"),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteArea(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteArea(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Delete Area"),
          content: Text("Are you sure you want to delete this area? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteArea(index);
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _startReordering() {
    setState(() {
      _originalAreas = List.from(areas);
      _isReordering = true;
    });
  }

  void _cancelReordering() {
    setState(() {
      areas = List.from(_originalAreas);
      _isReordering = false;
    });
  }

  void _acceptReordering() {
    setState(() {
      _isReordering = false;
    });
  }

  void _renameArea(int index) {
    TextEditingController _controller = TextEditingController(text: areas[index]['name']);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Rename Area"),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: "New Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final newName = _controller.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Please enter a new name.")),
                  );
                  return;
                }
                Navigator.pop(dialogContext); // Close input dialog

                // Show confirmation dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text("Confirm Rename"),
                    content: Text("Are you sure you want to rename this area to \"$newName\"?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text("OK"),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;

                // Call API to update
                try {
                  final areaId = int.parse(areas[index]['id']!);
                  final gardenId = int.parse(widget.gardenId!);
                  final prefs = await SharedPreferences.getInstance();
                  final accessToken = prefs.getString('accessToken');
                  final url = Uri.parse('https://chillguys.fun/area/upd');
                  final response = await http.put(
                    url,
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $accessToken',
                    },
                    body: jsonEncode({
                      'id': areaId,
                      'areaName': newName,
                      'gardenId': gardenId,
                    }),
                  );
                  final body = jsonDecode(response.body);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(body['message'] ?? "Rename result unknown.")),
                  );
                  if (response.statusCode == 200) {
                    _fetchAreas();
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

  Future<void> _deleteArea(int index) async {
    final areaIdStr = areas[index]['id'];
    if (areaIdStr == null) return;
    final areaId = int.parse(areaIdStr);

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final url = Uri.parse('https://chillguys.fun/area/del/$areaId');
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
          SnackBar(content: Text(body['message'] ?? "Area deleted successfully.")),
        );
        setState(() {
          areas.removeAt(index);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? "Failed to delete area.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
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
          "${widget.gardenName} Areas",
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
            onPressed: _addArea,
            tooltip: "Add Area",
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
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFFe8f5e9),
        ),
        child: Stack(
          children: [
            // Cartoon-style garden background
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
              painter: GardenBackgroundPainter(),
            ),
            // Content
            SafeArea(
              child: _loading
                  ? Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF388e3c)),
              ))
                  : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SizedBox(height: 12),
                    Expanded(
                      child: _isReordering
                          ? buildReorderableGrid()
                          : buildNormalGrid(),
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

  Widget buildReorderableGrid() {
    return ReorderableGridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: areas.length,
      dragEnabled: true,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) newIndex--;
          final item = areas.removeAt(oldIndex);
          areas.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        return Material(
          key: ValueKey(areas[index]),
          child: AreaItem(area: areas[index]),
        );
      },
    );
  }

  Widget buildNormalGrid() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: areas.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VaseScreen(
                  areaName: areas[index]['name'],
                  areaId: areas[index]['id'],
                ),
              ),
            );
          },
          onLongPress: () => _showOptions(index),
          child: AreaItem(area: areas[index]),
        );
      },
    );
  }
}

class AreaItem extends StatelessWidget {
  final Map<String, String> area;
  const AreaItem({required this.area});

  @override
  Widget build(BuildContext context) {
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
              child: CustomPaint(
                painter: AreaImagePainter(
                  // Use the area ID to create a bit of variety
                  colorSeed: int.tryParse(area['id'] ?? '1') ?? 1,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                area['name']!,
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

class AreaImagePainter extends CustomPainter {
  final int colorSeed;

  AreaImagePainter({required this.colorSeed});

  @override
  void paint(Canvas canvas, Size size) {
    // Base colors - we'll rotate these based on colorSeed
    final List<Color> plantColors = [
      Color(0xFF66bb6a),  // Green
      Color(0xFF4caf50),  // Medium green
      Color(0xFF81c784),  // Light green
      Color(0xFF388e3c),  // Dark green
    ];

    // Ground
    Paint groundPaint = Paint()..color = Color(0xFFc5e1a5);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3), groundPaint);

    // Garden row lines
    Paint linePaint = Paint()
      ..color = Color(0xFFa5d6a7)
      ..strokeWidth = 2;

    for (int i = 1; i < 4; i++) {
      double y = size.height * (0.7 + i * 0.07);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }

    // Draw small plants
    final int numPlants = 3 + (colorSeed % 3);
    for (int i = 0; i < numPlants; i++) {
      final xPos = size.width * (0.2 + 0.6 * i / (numPlants - 1));
      final yPos = size.height * 0.7;
      final plantHeight = size.height * (0.15 + 0.1 * ((colorSeed + i) % 3) / 2);
      final plantWidth = size.width * 0.15;
      final colorIndex = (colorSeed + i) % plantColors.length;

      _drawPlant(canvas, Offset(xPos, yPos), plantWidth, plantHeight, plantColors[colorIndex]);
    }

    // Maybe add a watering can or garden tool
    if (colorSeed % 4 == 0) {
      _drawWateringCan(canvas, Offset(size.width * 0.8, size.height * 0.6), size.width * 0.15);
    } else if (colorSeed % 4 == 1) {
      _drawGardenTool(canvas, Offset(size.width * 0.15, size.height * 0.6), size.width * 0.1);
    }
  }

  void _drawPlant(Canvas canvas, Offset position, double width, double height, Color color) {
    // Plant stem
    Paint stemPaint = Paint()
      ..color = Color(0xFF8d6e63)
      ..strokeWidth = width * 0.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      position,
      Offset(position.dx, position.dy - height * 0.7),
      stemPaint,
    );

    // Plant leaves
    Paint leafPaint = Paint()..color = color;

    // Draw a few leaves
    final leafSize = width * 0.8;
    canvas.drawCircle(
      Offset(position.dx - leafSize * 0.5, position.dy - height * 0.5),
      leafSize * 0.6,
      leafPaint,
    );
    canvas.drawCircle(
      Offset(position.dx + leafSize * 0.5, position.dy - height * 0.6),
      leafSize * 0.5,
      leafPaint,
    );
    canvas.drawCircle(
      Offset(position.dx, position.dy - height),
      leafSize * 0.7,
      leafPaint,
    );
  }

  void _drawWateringCan(Canvas canvas, Offset position, double size) {
    Paint canPaint = Paint()..color = Color(0xFF90a4ae);

    // Can body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: position,
          width: size * 1.2,
          height: size * 0.8,
        ),
        Radius.circular(size * 0.2),
      ),
      canPaint,
    );

    // Can spout
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          position.dx - size * 1.0,
          position.dy - size * 0.2,
          size * 0.8,
          size * 0.3,
        ),
        Radius.circular(size * 0.1),
      ),
      canPaint,
    );

    // Can handle
    Paint handlePaint = Paint()
      ..color = Color(0xFF78909c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.1;

    Path handlePath = Path()
      ..moveTo(position.dx, position.dy - size * 0.4)
      ..quadraticBezierTo(
        position.dx,
        position.dy - size * 0.8,
        position.dx,
        position.dy - size * 0.4,
      );

    canvas.drawPath(handlePath, handlePaint);
  }

  void _drawGardenTool(Canvas canvas, Offset position, double size) {
    // Draw a simple garden fork
    Paint handlePaint = Paint()..color = Color(0xFF8d6e63);
    Paint metalPaint = Paint()..color = Color(0xFFbdbdbd);

    // Handle
    canvas.drawRect(
      Rect.fromLTWH(
        position.dx - size * 0.1,
        position.dy - size * 2,
        size * 0.2,
        size * 2,
      ),
      handlePaint,
    );

    // Fork head
    canvas.drawRect(
      Rect.fromLTWH(
        position.dx - size * 0.4,
        position.dy,
        size * 0.8,
        size * 0.2,
      ),
      metalPaint,
    );

    // Fork tines
    for (int i = 0; i < 3; i++) {
      double x = position.dx - size * 0.3 + i * size * 0.3;
      canvas.drawRect(
        Rect.fromLTWH(
          x,
          position.dy + size * 0.2,
          size * 0.1,
          size * 0.5,
        ),
        metalPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}