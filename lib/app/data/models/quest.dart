class Quest {
  String description;
  int xpReward;
  int coinReward;
  bool isSecret;
  Quest(this.description, this.xpReward, this.coinReward,
      {this.isSecret = false});
}
