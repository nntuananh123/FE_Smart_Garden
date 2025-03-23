import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isReordering = false;
  List<Map<String, String>> plants = [
    {'name': 'Plant 1', 'image': 'assets/placeholder.png'},
    {'name': 'Plant 2', 'image': 'assets/placeholder.png'},
    {'name': 'Plant 3', 'image': 'assets/placeholder.png'},
    {'name': 'Plant 4', 'image': 'assets/placeholder.png'},
  ];

  late List<Map<String, String>> _originalPlants;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
                  _renamePlant(index);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text("Delete"),
                onTap: () {
                  Navigator.pop(context);
                  _deletePlant(index);
                },
              ),
            ],
          ),
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

  void _renamePlant(int index) {
    TextEditingController _controller =
    TextEditingController(text: plants[index]['name']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Rename Plant"),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: "New Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  plants[index]['name'] = _controller.text;
                });
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _deletePlant(int index) {
    setState(() {
      plants.removeAt(index);
    });
  }

  void _addPlant() {
    TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add new"),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: "Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  setState(() {
                    plants.add({
                      'name': _controller.text,
                      'image': 'assets/placeholder.png',
                    });
                  });
                }
                Navigator.pop(context);
              },
              child: Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Garden",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.grey),
            onPressed: _addPlant,
          ),
          if (_isReordering) ...[
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.red),
              onPressed: _cancelReordering,
            ),
            IconButton(
              icon: Icon(Icons.check, color: Colors.green),
              onPressed: _acceptReordering,
            ),
          ]
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isReordering ? buildReorderableGrid() : buildNormalGrid(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
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
          child: PlantItem(plant: plants[index]),
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
      itemCount: plants.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onLongPress: () => _showOptions(index),
          child: PlantItem(plant: plants[index]),
        );
      },
    );
  }
}

class PlantItem extends StatelessWidget {
  final Map<String, String> plant;
  const PlantItem({required this.plant});

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
              child: Icon(Icons.image, size: 50, color: Colors.grey),
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
