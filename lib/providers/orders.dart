import 'dart:convert';

import '../models/http_exception.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import './cart.dart';

class OrderItem {
  final String id;
  final double amount;
  final List<CartItem> products;
  final DateTime dateTime;

  OrderItem({
    @required this.id,
    @required this.amount,
    @required this.products,
    @required this.dateTime,
  });
}

class Orders with ChangeNotifier {
  List<OrderItem> _orders = [];

  final authToken;
  final userId;

  Orders(this.authToken, this._orders, this.userId);

  List<OrderItem> get orders {
    return [..._orders];
  }

  Future<void> fetchAndSetOrders() async {
    final queryParameters = {'auth': authToken};
    final url = Uri.parse(
        'https://first-flutter-app-inline-default-rtdb.firebaseio.com/orders/$userId.json?auth=$authToken');
    final response = await http.get(url);
    final List<OrderItem> loadedOrders = [];
    final extractedData = json.decode(response.body) as Map<String, dynamic>;
    if (extractedData == null) {
      return;
    }
    extractedData.forEach((orderId, orderData) {
      // print('before${orderData['products'].runtimeType}');
      // final orderDData = json.decode(orderData['products']);
      // print('after${orderDData.runtimeType}');
      loadedOrders.add(
        OrderItem(
          id: orderId,
          amount: orderData['amount'],
          dateTime: DateTime.parse(orderData['dateTime']),
          products: (orderData['products'] as List<dynamic>)
              .map(
                (item) => CartItem(
                  id: item['id'],
                  price: item['price'],
                  quantity: item['quantity'],
                  title: item['title'],
                ),
              )
              .toList(),
        ),
      );
    });
    _orders = loadedOrders.reversed.toList();
    notifyListeners();
  }

  Future<void> addOrder(List<CartItem> cartProducts, double total) async {
    final queryParameters2 = {'auth': authToken};
    final url = Uri.https(
        'first-flutter-app-inline-default-rtdb.firebaseio.com',
        '/orders/$userId.json',
        queryParameters2);
    final timestamp = DateTime.now();
    final products = cartProducts
        .map((cp) => {
              'id': cp.id,
              'title': cp.title,
              'quantity': cp.quantity,
              'price': cp.price,
            })
        .toList();
    final body = json.encode({
      'amount': total,
      'dateTime': timestamp.toIso8601String(),
      'products': products
    });

    final response = await http.post(url, body: body);
    _orders.insert(
      0,
      OrderItem(
        id: json.decode(response.body)['name'],
        amount: total,
        dateTime: timestamp,
        products: cartProducts,
      ),
    );
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    final deleteProductToken = {'auth': authToken};
    final url = Uri.https(
        'first-flutter-app-inline-default-rtdb.firebaseio.com',
        '/orders/$userId/$id.json',
        deleteProductToken);
    final existingProductIndex = _orders.indexWhere((prod) => prod.id == id);
    var existingProduct = _orders[existingProductIndex];
    _orders.removeAt(existingProductIndex);
    notifyListeners();
    final response = await http.delete(url);
    if (response.statusCode >= 400) {
      _orders.insert(existingProductIndex, existingProduct);
      notifyListeners();
      throw HttpException('Could not delete product.');
    }
    existingProduct = null;
  }
}
