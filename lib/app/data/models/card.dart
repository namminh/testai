class Cards {
  final String id;
  final String name;
  final String description;
  final String imagePath;
  final int rarity;
  final String type;
  final int attack;
  final int defense;
  final String element;
  final String? effect;

  Cards({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.rarity,
    required this.type,
    required this.attack,
    required this.defense,
    required this.element,
    this.effect,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'imagePath': imagePath,
        'rarity': rarity,
        'type': type,
        'attack': attack,
        'defense': defense,
        'element': element,
        'effect': effect,
      };

  factory Cards.fromJson(Map<String, dynamic> json) => Cards(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        imagePath: json['imagePath'],
        rarity: json['rarity'],
        type: json['type'],
        attack: json['attack'],
        defense: json['defense'],
        element: json['element'],
        effect: json['effect'],
      );
}
