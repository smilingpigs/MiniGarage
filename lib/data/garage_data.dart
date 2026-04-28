class CartItem {
  final String id;
  final String title;
  final int price;
  final String imageUrl;
  final String sellerPhone;
  final String scale;
  final bool isTradeOnly;

CartItem({
  required this.id,
  required this.title,
  required this.price,
  required this.imageUrl,
  required this.sellerPhone,
  required this.scale,
  this.isTradeOnly = false,
});
}

List<CartItem> garageBag = [];