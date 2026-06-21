import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_p12/model/product.dart';

class ApiService {
  static const String baseUrl = 'http://10.120.217.225:8000/api';
  static const String storageUrl = 'http://10.120.217.225:8000/storage';

static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    String cleanPath = imagePath.replaceAll('\\', '/');

    if (cleanPath.startsWith('public/')) {
      cleanPath = cleanPath.substring(7);
    }

    String base = storageUrl.endsWith('/') ? storageUrl : '$storageUrl/';
    String path = cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;

    final String finalUrl = base + path;

    print('=== DEBUG GAMBAR LOKAL ===');
    print('URL Gambar Asli: $finalUrl');

    return finalUrl; // <-- Kembalikan ke finalUrl murni!
  }

  // GET PRODUCTS - FIXED: Handle berbagai format response
  static Future<List<Product>> getProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/product'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // FIX: Handle response yang berbeda format
        if (decoded is List) {
          // Response berupa array/list langsung
          print('Response adalah List dengan ${decoded.length} item');
          return decoded.map((json) => Product.fromJson(json)).toList();
        } 
        else if (decoded is Map<String, dynamic>) {
          // Response berupa object
          print('Response adalah Map dengan keys: ${decoded.keys}');

          // Cek apakah ada key 'data' yang berisi list
          if (decoded.containsKey('data') && decoded['data'] is List) {
            return (decoded['data'] as List)
                .map((json) => Product.fromJson(json))
                .toList();
          }
          // Cek apakah ada key 'products' yang berisi list
          else if (decoded.containsKey('products') && decoded['products'] is List) {
            return (decoded['products'] as List)
                .map((json) => Product.fromJson(json))
                .toList();
          }
          // Cek apakah ada key 'result' yang berisi list
          else if (decoded.containsKey('result') && decoded['result'] is List) {
            return (decoded['result'] as List)
                .map((json) => Product.fromJson(json))
                .toList();
          }
          // Jika hanya object tunggal, bungkus dalam list
          else {
            print('Response adalah object tunggal, membungkus ke dalam list');
            return [Product.fromJson(decoded)];
          }
        } 
        else {
          throw Exception('Format response tidak dikenali: ${decoded.runtimeType}');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint tidak ditemukan: $baseUrl/product');
      } else {
        throw Exception('Gagal memuat produk: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getProducts: $e');
      throw Exception('Error: $e');
    }
  }

  // GET PRODUCT BY ID - FIXED
  static Future<Product> getProductById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/product/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('Get Product By ID Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded is Map<String, dynamic>) {
          // Cek apakah ada wrapper
          if (decoded.containsKey('data') && decoded['data'] is Map) {
            return Product.fromJson(decoded['data']);
          }
          return Product.fromJson(decoded);
        } else {
          throw Exception('Format response tidak dikenali');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Produk tidak ditemukan');
      } else {
        throw Exception('Gagal memuat produk: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // REDUCE STOCK - FIXED
  static Future<Product> reduceStock(int productId, int quantity) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/product/$productId/reduce-stock'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'quantity': quantity}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map) {
            return Product.fromJson(decoded['data']);
          }
          return Product.fromJson(decoded);
        }
        throw Exception('Format response tidak dikenali');
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Stok tidak mencukupi');
      } else {
        throw Exception('Gagal mengurangi stok: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // DELETE PRODUCT
  static Future<void> deleteProduct(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/product/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Gagal menghapus produk: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // CREATE PRODUCT
static Future<Product> createProduct({
  required String name,
  required String descriptions,
  required int price,
  required int stock,
  File? imageFile, // Tambahkan parameter ini
  Uint8List? webImageBytes, // Tambahkan parameter ini
}) async {
  try {
    // 1. Gunakan MultipartRequest agar bisa mengirim file
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/product'));

    // 2. Tambahkan data teks ke fields
    request.fields['name'] = name;
    request.fields['descriptions'] = descriptions;
    request.fields['price'] = price.toString();
    request.fields['stock'] = stock.toString();
    request.headers['Accept'] = 'application/json';

    // 3. Tambahkan file gambar jika ada
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    } else if (webImageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          webImageBytes,
          filename: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
    }

    // 4. Kirim request
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    print('Create Product Status: ${response.statusCode}');
    print('Create Product Body: $responseBody');

    if (response.statusCode == 201) {
      final decoded = json.decode(responseBody);
      // Sesuaikan dengan struktur JSON yang dikembalikan API Anda
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('data') && decoded['data'] is Map) {
          return Product.fromJson(decoded['data']);
        }
        return Product.fromJson(decoded);
      }
      throw Exception('Format response tidak dikenali');
    } else {
      throw Exception('Gagal membuat produk: ${response.statusCode}');
    }
  } catch (e) {
    print('Create Product Error: $e');
    throw Exception('Error: $e');
  }
}

  // UPDATE PRODUCT
  static Future<Product> updateProduct({
    required int id,
    String? name,
    String? descriptions,
    int? price,
    int? stock,
    File? imageFile,
    Uint8List? imageBytes,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/product/$id'),
      );

      request.fields['_method'] = 'PUT';

      if (name != null && name.isNotEmpty) {
        request.fields['name'] = name;
      }
      if (descriptions != null) {
        request.fields['descriptions'] = descriptions;
      }
      if (price != null) {
        request.fields['price'] = price.toString();
      }
      if (stock != null) {
        request.fields['stock'] = stock.toString();
      }

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      } else if (imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Update Product Response Status: ${response.statusCode}');
      print('Update Product Response Body: $responseBody');

      if (response.statusCode == 200) {
        final decoded = json.decode(responseBody);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map) {
            return Product.fromJson(decoded['data']);
          }
          return Product.fromJson(decoded);
        }
        throw Exception('Format response tidak dikenali');
      } else {
        try {
          final error = json.decode(responseBody);
          throw Exception(error['message'] ?? 'Gagal update produk');
        } catch (e) {
          throw Exception('Gagal update produk: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Update Product Error: $e');
      throw Exception('Error: $e');
    }
  }

  // DEBUG: Test API Response
  static Future<void> testApiResponse() async {
    try {
      print('Testing API Response...');
      final response = await http.get(
        Uri.parse('$baseUrl/product'),
      ).timeout(const Duration(seconds: 10));

      print('Status Code: ${response.statusCode}');
      print('Response Type: ${response.runtimeType}');
      print('Response Body: ${response.body}');

      final decoded = json.decode(response.body);
      print('Decoded Type: ${decoded.runtimeType}');

      if (decoded is List) {
        print('Response adalah List dengan ${decoded.length} item');
      } else if (decoded is Map) {
        print('Response adalah Map dengan keys: ${decoded.keys}');
        if (decoded.containsKey('data')) {
          print('Key "data" ditemukan dengan tipe: ${decoded['data'].runtimeType}');
        }
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Upload Image - VERSI BYTES
  static Future<String> uploadImage(int productId, File? imageFile, Uint8List? imageBytes) async {
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/product/$productId/upload-image'),
    );

    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    } else if (imageBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
    } else {
      throw Exception('Tidak ada file atau data gambar untuk diupload');
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final decoded = json.decode(responseBody);
      // PERBAIKAN: Cek apakah decoded bukan null
      if (decoded != null && decoded is Map) {
        return decoded['image_url']?.toString() ?? '';
      }
      return '';
    } else {
      throw Exception('Upload gagal: ${response.statusCode}');
    }
  } catch (e) {
    print('Upload image error: $e');
    throw Exception('Gagal upload gambar: $e');
  }
}
  }