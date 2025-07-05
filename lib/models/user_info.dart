class UserInfo {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String gender;
  final String birthday;
  final String username;

  UserInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.gender,
    required this.birthday,
    required this.username,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      phone: json['phone'],
      gender: json['gender'],
      birthday: json['birthday'],
      username: json['username'],
    );
  }
}