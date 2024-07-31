import 'package:chat/menu.dart';
import 'package:chat/screens/chat_screen.dart';
import 'package:chat/screens/map_geo.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // criar coleção formandos no Firebase
  final CollectionReference _formandos =
      FirebaseFirestore.instance.collection('formandos');
  // adicionar documentos para teste
  // _formandos.add({'nome': 'Bernardo', 'fone': '991690252'});
  // _formandos.add({'nome': 'Camila', 'fone': '991690252'});
  // atualizar documento com base no ID
  _formandos.doc('ah0h5bL7Rj6BXknx3bLw').update({'fone': '111111'});
  // deletar documento com base no ID
  // _formandos.doc('ah0h5bL7Rj6BXknx3bLw').delete();

  // fazer busca pelos documentos
  QuerySnapshot snapshot = await _formandos.get();
  snapshot.docs.forEach((element) {
    print(element.data().toString());
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: NavigationOptions(),
      //ChatScreen(),
    );
  }
}
