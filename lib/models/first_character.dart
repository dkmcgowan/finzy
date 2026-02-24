class FirstCharacter {
  final String key;
  final String title;
  final int size;

  FirstCharacter({required this.key, required this.title, required this.size});

  factory FirstCharacter.fromJson(Map<String, dynamic> json) {
    return FirstCharacter(key: json['key'] ?? '', title: json['title'] ?? '', size: json['size'] ?? 0);
  }
}
