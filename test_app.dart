import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      title: 'Teste',
      home: Scaffold(
        appBar: AppBar(title: const Text('Teste')),
        body: const Center(
          child: Text('App está rodando!'),
        ),
      ),
    ),
  );
}
