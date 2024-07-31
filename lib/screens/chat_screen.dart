import 'dart:io';
import 'package:chat/screens/text_message.dart';
import '/screens/text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ChatScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return ChatScreenState();
  }
}

class ChatScreenState extends State<ChatScreen> {
  final CollectionReference _mensagens =
      FirebaseFirestore.instance.collection("mensagens");

  // objetos referentes ao login
  final GoogleSignIn googleSignIn = GoogleSignIn();
  User? _currentUser;
  FirebaseAuth auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // controle do componente de carregamento
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(_currentUser != null
              ? 'Olá, ${_currentUser?.displayName}'
              : 'Chat App'),
          actions: <Widget>[
            _currentUser != null
                ? IconButton(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                      const snackBar = SnackBar(
                          content: Text('Logout'), backgroundColor: Colors.red);
                    },
                    icon: Icon(Icons.exit_to_app))
                : Container()
          ],
          backgroundColor: Colors.cyan,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
                child: StreamBuilder<QuerySnapshot>(
              stream: _mensagens.orderBy('time').snapshots(),
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return Center(child: CircularProgressIndicator());
                  default:
                    List<DocumentSnapshot> documents =
                        snapshot.data!.docs.reversed.toList();
                    return ListView.builder(
                      itemCount: documents.length,
                      reverse: true,
                      itemBuilder: (context, index) {
                        return TextMessage(documents[index],
                            documents[index].get('uid') == _currentUser?.uid);
                      },
                    );
                }
              },
            )),
            _isLoading ? LinearProgressIndicator() : Container(),
            TextComposer(_sendMessage),
          ],
        ));
  }

  // envio de texto ou imagem -> só permitir caso usuário esteja autenticado
  void _sendMessage({String? text, XFile? imgFile}) async {
    final CollectionReference _mensagens =
        FirebaseFirestore.instance.collection("mensagens");

    // informações do usuário logado
    String id = '';
    User? user = await _getUser(context: context);

    // caso usuário não efetue o login, exibe mensagem e não permite continuar (return)
    if (user == null) {
      const snackbar = SnackBar(
          content: Text('Não foi possível fazer login!'),
          backgroundColor: Colors.red);
      ScaffoldMessenger.of(context).showSnackBar(snackbar);
      return;
    }

    // INÍCIO DO CARREGAMENTO DA MENSAGEM ENVIADA -> adicionar loading
    setState(() {
      _isLoading = true;
    });

    // dados da mensagem
    Map<String, dynamic> data = {
      'time': Timestamp.now(),
      'url': '',
      'text': '',
      'uid': user?.uid, // identificador do usuário
      'senderName': user?.displayName, // nome do usuário que envia a mensagem
      'senderPhotoUrl': user?.photoURL // foto do usuário que envia a mensagem
    };

    if (user != null) id = user.uid;

    if (imgFile != null) {
      // chegou um arquivo de imagem
      firebase_storage.UploadTask uploadTask;
      firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance
          .ref()
          .child("imgs")
          .child(id + DateTime.now().millisecondsSinceEpoch.toString());
      final metadados = firebase_storage.SettableMetadata(
          contentType: "image/jpeg",
          customMetadata: {"picked-file-path": imgFile.path});
      if (kIsWeb) {
        // se estiver na plataforma WEB
        uploadTask = ref.putData(await imgFile.readAsBytes(), metadados);
      } else {
        // se for outra plataforma
        uploadTask = ref.putFile(File(imgFile.path), metadados);
      }
      var taskSnapshot = await uploadTask;
      String imageUrl = "";
      imageUrl =
          await taskSnapshot.ref.getDownloadURL(); //URL da imagem no storage
      data['url'] = imageUrl;
    } else {
      // se chegou apenas texto
      data['text'] = text;
    }
    _mensagens.add(data);

    // FIM DO CARREGAMENTO DA MENSAGEM ENVIADA -> tirar loading
    setState(() {
      _isLoading = false;
    });
  }

  // métodos referentes ao login
  Future<User?> _getUser({required BuildContext context}) async {
    User? user; // pode ser nulo pq login falho retorna null

    // caso já tenha feito um login válido
    if (_currentUser != null) return _currentUser;

    if (kIsWeb) {
      //WEB
      GoogleAuthProvider authProvider = GoogleAuthProvider();
      try {
        // pop-up de login Google para receber a credencial (dados) do usuário
        final UserCredential userCredential =
            await auth.signInWithPopup(authProvider);
        user = userCredential.user;
      } catch (e) {
        print(e);
      }
    } else {
      //ANDROID
      // página de login da conta Google
      final GoogleSignInAccount? googleSignInAccount =
          await googleSignIn.signIn();

      // verifica se a conta Google foi logada (!= de null) e recupera a autenticação
      if (googleSignInAccount != null) {
        final GoogleSignInAuthentication googleSignInAuthentication =
            await googleSignInAccount.authentication;

        // cria uma credencial com a autenticação obtida
        final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleSignInAuthentication.accessToken,
            idToken: googleSignInAuthentication.idToken);

        try {
          // a partir da credencial criada, recupera os dados do usuário
          final UserCredential userCredential =
              await auth.signInWithCredential(credential);
          user = userCredential.user;
        } catch (e) {
          print(e);
        }
      }
      print("User logado: " + user!.displayName.toString());
    }
    return user;
  }

  // método que, ao abrir a página de ChatScreen, habiblita um ouvinte (listener)
  // que, a qualquer alteração de autenticação, atualiza o estado do usuário _currentUser
  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user;
      });
    });
  }
}
