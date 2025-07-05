class ApiError {
  final int status;
  final String error;
  final String message;

  ApiError({required this.status, required this.error, required this.message});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      status: json['status'],
      error: json['error'],
      message: json['message'],
    );
  }
}