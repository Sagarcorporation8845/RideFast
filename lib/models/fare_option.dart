class FareOption {
  final String vehicleCategory;
  final String? subCategory;
  final String displayName;
  final double amount;
  final String fareId;

  FareOption({
    required this.vehicleCategory,
    this.subCategory,
    required this.displayName,
    required this.amount,
    required this.fareId,
  });

  factory FareOption.fromJson(Map<String, dynamic> json) {
    return FareOption(
      vehicleCategory: json['vehicle_category'],
      subCategory: json['sub_category'],
      displayName: json['display_name'],
      amount: (json['amount'] as num).toDouble(),
      fareId: json['fareId'],
    );
  }

  // Helper to get the correct image path based on category
  String get imagePath {
    switch (vehicleCategory) {
      case 'bike':
        return 'assets/images/bike_icon.png';
      case 'auto':
        return 'assets/images/auto_icon.png';
      case 'car':
        switch (subCategory) {
          case 'economy':
            return 'assets/images/mini_icon.png';
          case 'premium':
            return 'assets/images/sedan_icon.png';
          case 'XL':
            return 'assets/images/suv_icon.png';
          default:
            return 'assets/images/mini_icon.png';
        }
      default:
        return 'assets/images/mini_icon.png';
    }
  }

  // **NEW**: A unique key for sorting. e.g., 'car_economy'
  String get sortKey {
    if (subCategory != null && subCategory!.isNotEmpty) {
      return '${vehicleCategory}_$subCategory';
    }
    return vehicleCategory;
  }
}

