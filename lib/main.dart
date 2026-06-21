// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_p12/produk/list_product.dart'; // Patokan halaman utama

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Menghilangkan banner debug di pojok kanan atas
      title: 'Mattz Store',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Mengaktifkan desain Material 3 yang lebih modern
      ),
      home: const ProductListScreen(), // Mengatur halaman pertama yang muncul saat aplikasi dibuka
    );
  }
}