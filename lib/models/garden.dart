class Garden {
  final int id;
  final String gardenName;
  final int userId;

  Garden({required this.id, required this.gardenName, required this.userId});

  factory Garden.fromJson(Map<String, dynamic> json) {
    return Garden(
      id: json['id'],
      gardenName: json['gardenName'],
      userId: json['userId'],
    );
  }
}

class GardenListResponse {
  final int pageNumber;
  final int pageSize;
  final int totalPages;
  final int totalElements;
  final List<Garden> gardens;

  GardenListResponse({
    required this.pageNumber,
    required this.pageSize,
    required this.totalPages,
    required this.totalElements,
    required this.gardens,
  });

  factory GardenListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return GardenListResponse(
      pageNumber: data['pageNumber'],
      pageSize: data['pageSize'],
      totalPages: data['totalPages'],
      totalElements: data['totalElements'],
      gardens: (data['gardens'] as List)
          .map((e) => Garden.fromJson(e))
          .toList(),
    );
  }
}