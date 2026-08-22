class AppUser{
  final String username;
  final String fullName;
  final String password;
  final String role;

  AppUser({
    required this.username,
    required this.fullName,
    required this.password,
    required this.role
  });
}

List<AppUser> mockUserDatabase = [
  AppUser(
      username: 'admin@gmail.com',
      fullName: 'Booi Ah Heng',
      password: 'Admin12345@',
      role: 'Staff'
  ),
  AppUser(
      username: 'user@gmail.com',
      fullName: 'Ger Ah Heng',
      password: 'User12345@',
      role: 'User'
  )
];