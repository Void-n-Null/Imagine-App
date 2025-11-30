import '../../bestbuy/bestbuy.dart';
import '../../storage/cart_service.dart';
import '../tool.dart';
import '../../../config/api_keys.dart';

/// Tool for adding a product to the shopping cart.
class AddToCartTool extends Tool {
  final BestBuyClient _client;

  AddToCartTool({BestBuyClient? client})
      : _client = client ?? BestBuyClient(apiKey: ApiKeys.bestBuy);

  @override
  String get name => 'add_to_cart';

  @override
  String get displayName => 'Adding to Cart...';

  @override
  String get description => '''Add a product to the user's shopping cart.
Requires the product SKU. The cart persists across sessions.
Use this when the user wants to save a product for later or add it to their list.''';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'sku': {
            'type': 'integer',
            'description': 'The Best Buy SKU of the product to add to cart.',
          },
        },
        'required': ['sku'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final sku = args['sku'] as int?;
      if (sku == null) {
        return 'Error: SKU is required to add a product to cart.';
      }

      final cart = CartService.instance;

      // Check if already in cart
      if (cart.containsSku(sku)) {
        final item = cart.getItemBySku(sku);
        return 'Product "${item?.name ?? 'SKU $sku'}" is already in your cart.';
      }

      // Fetch product details
      final product = await _client.getProductBySku(sku);
      if (product == null) {
        return 'Error: Could not find product with SKU $sku.';
      }

      // Add to cart
      await cart.addToCart(product);

      return '''Successfully added to cart:
- **${product.name}**
- SKU: ${product.sku}
- Price: \$${product.effectivePrice?.toStringAsFixed(2) ?? 'N/A'}

Cart now has ${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}.''';
    } catch (e) {
      return 'Error adding to cart: $e';
    }
  }
}

/// Tool for removing a product from the shopping cart.
class RemoveFromCartTool extends Tool {
  @override
  String get name => 'remove_from_cart';

  @override
  String get displayName => 'Removing from Cart...';

  @override
  String get description => '''Remove a product from the user's shopping cart.
Requires the product SKU. Use this when the user no longer wants a product in their cart.''';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'sku': {
            'type': 'integer',
            'description': 'The Best Buy SKU of the product to remove from cart.',
          },
        },
        'required': ['sku'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final sku = args['sku'] as int?;
      if (sku == null) {
        return 'Error: SKU is required to remove a product from cart.';
      }

      final cart = CartService.instance;
      final item = cart.getItemBySku(sku);

      if (item == null) {
        return 'Product with SKU $sku is not in your cart.';
      }

      final productName = item.name;
      await cart.removeFromCart(sku);

      return '''Removed "$productName" from your cart.

Cart now has ${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}.''';
    } catch (e) {
      return 'Error removing from cart: $e';
    }
  }
}

/// Tool for clearing all items from the shopping cart.
class ClearCartTool extends Tool {
  @override
  String get name => 'clear_cart';

  @override
  String get displayName => 'Clearing Cart...';

  @override
  String get description => '''Clear all products from the user's shopping cart.
Use this when the user wants to start fresh or remove everything.
This action cannot be undone.''';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {},
        'required': [],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final cart = CartService.instance;
      final itemCount = cart.itemCount;

      if (itemCount == 0) {
        return 'Your cart is already empty.';
      }

      await cart.clearCart();

      return 'Cleared $itemCount item${itemCount == 1 ? '' : 's'} from your cart. Your cart is now empty.';
    } catch (e) {
      return 'Error clearing cart: $e';
    }
  }
}

/// Tool for viewing the contents of the shopping cart.
class ViewCartTool extends Tool {
  @override
  String get name => 'view_cart';

  @override
  String get displayName => 'Checking Cart...';

  @override
  String get description => '''View the contents of the user's shopping cart.
Can optionally search for specific items using a fuzzy name search.
Returns the list of products with their SKUs, names, and prices.''';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'search': {
            'type': 'string',
            'description':
                'Optional search query to find specific items in the cart. Uses fuzzy matching on product names.',
          },
        },
        'required': [],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final cart = CartService.instance;
      final searchQuery = args['search'] as String?;

      if (cart.isEmpty) {
        return 'Your cart is empty. Use add_to_cart to add products.';
      }

      List<CartItem> items;
      String header;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        items = cart.searchItems(searchQuery);
        if (items.isEmpty) {
          return 'No items in your cart match "$searchQuery". You have ${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} total.';
        }
        header = 'Found ${items.length} matching item${items.length == 1 ? '' : 's'} for "$searchQuery":';
      } else {
        items = cart.items;
        header = 'Your cart has ${items.length} item${items.length == 1 ? '' : 's'}:';
      }

      final buffer = StringBuffer();
      buffer.writeln(header);
      buffer.writeln();

      double total = 0;
      for (final item in items) {
        buffer.writeln('---');
        buffer.writeln('**${item.name}**');
        buffer.writeln('- SKU: ${item.sku}');
        if (item.manufacturer != null) {
          buffer.writeln('- Brand: ${item.manufacturer}');
        }
        if (item.price != null) {
          buffer.writeln('- Price: \$${item.price!.toStringAsFixed(2)}');
          total += item.price!;
        }
        if (item.upc != null) {
          buffer.writeln('- UPC: ${item.upc}');
        }
        buffer.writeln();
      }

      buffer.writeln('---');
      if (total > 0) {
        buffer.writeln('**Estimated Total: \$${total.toStringAsFixed(2)}**');
      }
      buffer.writeln();
      buffer.writeln('To show a product, use: [Product(SKU)]');

      return buffer.toString();
    } catch (e) {
      return 'Error viewing cart: $e';
    }
  }
}
