enum BabyReaction {
  responded,
  calmed,
  noResponse,
}

extension BabyReactionX on BabyReaction {
  String get emoji {
    switch (this) {
      case BabyReaction.responded:
        return '😊';
      case BabyReaction.calmed:
        return '😌';
      case BabyReaction.noResponse:
        return '😐';
    }
  }

  String get label {
    switch (this) {
      case BabyReaction.responded:
        return '有回应';
      case BabyReaction.calmed:
        return '安静了';
      case BabyReaction.noResponse:
        return '没反应';
    }
  }

  String get feedbackCopy {
    switch (this) {
      case BabyReaction.responded:
        return '记下来了，小禾给你下一句。';
      case BabyReaction.calmed:
        return '记下来了，这句可以留着用。';
      case BabyReaction.noResponse:
        return '没关系，换一句试试。';
    }
  }
}
