class HeroAvatar {
  final String name;
  final String url;

  const HeroAvatar({required this.name, required this.url});
}

class HeroAvatars {
  static const String _base =
      'https://cdn.jsdelivr.net/gh/akabab/superhero-api@0.3.0/api/images/md';

  static const List<HeroAvatar> all = [
    HeroAvatar(name: 'Spider-Man', url: '$_base/620-spider-man.jpg'),
    HeroAvatar(name: 'Batman', url: '$_base/69-batman.jpg'),
    HeroAvatar(name: 'Superman', url: '$_base/644-superman.jpg'),
    HeroAvatar(name: 'Iron Man', url: '$_base/346-iron-man.jpg'),
    HeroAvatar(name: 'Thor', url: '$_base/659-thor.jpg'),
    HeroAvatar(name: 'Captain America', url: '$_base/149-captain-america.jpg'),
    HeroAvatar(name: 'Hulk', url: '$_base/332-hulk.jpg'),
    HeroAvatar(name: 'Wolverine', url: '$_base/717-wolverine.jpg'),
    HeroAvatar(name: 'The Flash', url: '$_base/263-flash.jpg'),
    HeroAvatar(name: 'Wonder Woman', url: '$_base/720-wonder-woman.jpg'),
  ];

  static String random() {
    final index = DateTime.now().millisecondsSinceEpoch % all.length;
    return all[index].url;
  }

  static String nameFor(String url) {
    for (final h in all) {
      if (h.url == url) return h.name;
    }
    return '';
  }
}
