enum PracticeScene {
  feeding,
  drinking,
  diaper,
  bath,
  bedtime,
  outing,
}

extension PracticeSceneX on PracticeScene {
  static const allScenes = PracticeScene.values;

  String get label {
    switch (this) {
      case PracticeScene.feeding:
        return '吃饭时间';
      case PracticeScene.drinking:
        return '喝水时间';
      case PracticeScene.diaper:
        return '换尿布';
      case PracticeScene.bath:
        return '洗澡时间';
      case PracticeScene.bedtime:
        return '睡前时光';
      case PracticeScene.outing:
        return '出门时光';
    }
  }

  String get emoji {
    switch (this) {
      case PracticeScene.feeding:
        return '🍚';
      case PracticeScene.drinking:
        return '🥤';
      case PracticeScene.diaper:
        return '👶';
      case PracticeScene.bath:
        return '🛁';
      case PracticeScene.bedtime:
        return '🌙';
      case PracticeScene.outing:
        return '🚶';
    }
  }

  String get mentorBubbleCopy {
    switch (this) {
      case PracticeScene.feeding:
        return '喂饭时轻轻说，宝宝会听的。';
      case PracticeScene.drinking:
        return '递水的时候说一句就好。';
      case PracticeScene.diaper:
        return '换尿布时说，宝宝反而更安静。';
      case PracticeScene.bath:
        return '洗澡时说，宝宝会觉得好玩。';
      case PracticeScene.bedtime:
        return '睡前轻轻说，像讲故事一样。';
      case PracticeScene.outing:
        return '出门前说一句，今天就开始了。';
    }
  }

  String get completionTitle {
    switch (this) {
      case PracticeScene.feeding:
        return '喂饭时说的这句，下次还能用。';
      case PracticeScene.drinking:
        return '喝水时说的这句，明天还能用。';
      case PracticeScene.diaper:
        return '换尿布时说的这句，宝宝会慢慢习惯。';
      case PracticeScene.bath:
        return '洗澡时说的这句，宝宝会觉得好玩。';
      case PracticeScene.bedtime:
        return '睡前说的这句，会变成你们的小仪式。';
      case PracticeScene.outing:
        return '出门前说的这句，今天就开始了。';
    }
  }

  static PracticeScene defaultSceneForHour(int hour) {
    if (hour >= 7 && hour <= 9) return PracticeScene.feeding;
    if (hour >= 10 && hour <= 11) return PracticeScene.drinking;
    if (hour >= 12 && hour <= 14) return PracticeScene.diaper;
    if (hour >= 15 && hour <= 17) return PracticeScene.bath;
    if (hour >= 18 && hour <= 21) return PracticeScene.bedtime;
    return PracticeScene.outing;
  }
}
