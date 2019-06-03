import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lynight/authentification/primary_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lynight/services/clubPictures.dart';
import 'package:lynight/services/crud.dart';
import 'package:lynight/nightCubPage/nightClubProfile.dart';
import 'dart:async';
import 'package:lynight/qrCode/qrCodeGeneration.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as I;

class SumUp extends StatefulWidget {
  final clubId;

  SumUp({this.clubId});

  @override
  State<StatefulWidget> createState() {
    return _SumUpState();
  }
}

class _SumUpState extends State<SumUp> {
  final DateFormat dateFormat = DateFormat('dd-MM-yyyy');

  DateTime selectedDate = DateTime.now();
  GlobalKey globalKey = new GlobalKey();
  CrudMethods crudObj = CrudMethods();
  List reservation;
  var formatByte;
  var qrImage;

  final Shader linearGradient = LinearGradient(
    colors: <Color>[Colors.pink, Colors.deepPurple],
  ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0));

  void initState() {
    super.initState();
    //permet de choper la liste de toute les reservations
    crudObj.getDataFromUserFromDocument().then((value) {
      // correspond à await Firestore.instance.collection('user').document(user.uid).get();
      Map<String, dynamic> dataMap = value
          .data; // retourne la Map des donné de l'utilisateur correspondant à uid passé dans la methode venant du cruObj
      List reservationList = dataMap['reservation'];
      print(reservationList);
      setState(() {
        reservation = reservationList;
      });
    });
  }

  Future<Uint8List> _getWidgetImage() async {
    try {
      RenderRepaintBoundary boundary =
          globalKey.currentContext.findRenderObject();
      var image = await boundary.toImage();
      ByteData byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List pngBytes = byteData.buffer.asUint8List();
      I.Image imgFile = I.decodeImage(pngBytes);
//      var test = I.encodePng(imgFile);

      final Directory systemTempDir = Directory.systemTemp;
      final File file =
          await new File('${systemTempDir.path}/tempimage.png').create();
      file.writeAsBytes(pngBytes);

//      var bs64 = base64Encode(pngBytes);
      print(pngBytes);
      setState(() {
        formatByte = pngBytes;
        qrImage = file;
      });
      uploadQrCodeToFirestore();
    } catch (exception) {
      print(exception.toString());
    }
  }

  uploadQrCodeToFirestore() async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    var random = new Random();
    final StorageReference firebaseStorageRef = FirebaseStorage.instance
        .ref()
        .child('reservations/${user.uid}/${random.nextInt(9999)}.png');
    final StorageUploadTask task = firebaseStorageRef.putFile(qrImage);
    if (task.isInProgress) {
//      setState(() {
//        _isLoading = true;
//      });
    }
    var downloadUrl = await (await task.onComplete).ref.getDownloadURL();
    var url = downloadUrl.toString();
    addReservationToProfil(url);
    setState(() {
//      _isLoading = false;
    });
//    Navigator.pop(context);
  }

  addReservationToProfil(reservationUrl) async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    Map<String, dynamic> reservationInfo = {
      'boiteID': widget.clubId,
      'date': selectedDate,
      'qrcode': reservationUrl
    };

    var mutableListOfReservation = new List.from(reservation);

    mutableListOfReservation.add(reservationInfo);

    Firestore.instance
        .collection('user')
        .document(user.uid)
        .updateData({"reservation": mutableListOfReservation});
//    crudObj.createOrUpdateUserData(userMap);
  }

  Future<Null> _selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2019),
        lastDate: DateTime(2100));
    if (picked != null && picked != selectedDate)
      setState(() {
        selectedDate = picked;
      });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Firestore.instance
          .collection('club')
          .document(widget.clubId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        var clubData = snapshot.data;
        return pageConstruct(clubData, context);
      },
    );
  }

  Widget userBottomSection(clubData, context) {
    return Container(
      margin: EdgeInsets.only(top: 30.0),
      child:
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                alignment: FractionalOffset.center,
//                margin: EdgeInsets.only(left: 10.0),
                height: 400,
                width: 300,
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        clubData['name'],
                        style: TextStyle(
                          fontSize: 30.0,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()..shader = linearGradient
                        ),
                      ),
                    ),
                    Container(
                      height: 20,
                    ),
                    Container(
                      padding: EdgeInsets.only(top: 16),
                      width: MediaQuery.of(context).size.width,
                      height: 300,

                      decoration: BoxDecoration(
                        color: Colors.white70,
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey,
                            offset: Offset(2.0, 5.0),
                            blurRadius: 10.0,
                          )
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            leading: Icon(Icons.description),
                            title: Text("Description",
                              style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 18.0),
                            ),
                            subtitle: Container(
                                alignment: FractionalOffset.centerLeft,
                                child: Text(
                                  clubData['description'],
                                  style: TextStyle(fontSize: 15.0),
                                )
                            ),
                          ),
                          Container(
                            height: 10,
                          ),
                          ListTile(
                            leading: Icon(Icons.access_time),
                            title: Text(
                              "Date",
                              style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 18.0),
                            ),
                            subtitle: Container(
                              alignment: FractionalOffset.centerLeft,
                              child: Column(
                                children: <Widget>[
                                  Text(
                                      'Date choisie: ' +
                                          dateFormat.format(selectedDate),
                                      style: TextStyle(
                                        fontSize: 15.0,
                                      )),
                                  RaisedButton(
                                    elevation: 5.0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(5.0)),
                                    child: Text('Choisir une date',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16.0)),
                                    color: Theme.of(context).primaryColor,
                                    textColor: Colors.black87,
                                    onPressed: () {
                                      _selectDate(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            height: 10,
                          ),
                          ListTile(
                            leading: Icon(Icons.info),
                            title: Text(
                              "Informations utiles",
                              style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 18.0),
                            ),
                            subtitle: Container(
                                alignment: FractionalOffset.centerLeft,
                                child: Text(
                                  clubData['adress'] +
                                      '\n' +
                                      '\n' +
                                      clubData['phone'],
                                  style: TextStyle(fontSize: 15.0),
                                )),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buttonGenerateQrCode() {
    return Column(
      children: <Widget>[
        Stack(children: <Widget>[
          Opacity(
            opacity: 0.1,
            child: Column(
              children: [
                RepaintBoundary(
                  key: globalKey,
                  child: QrImage(
                    data: "jeremy",
                    size: 200.0,
                    version: 8,
                    backgroundColor: Colors.white,
                  ),
                )
              ],
            ),
          ),
          RaisedButton(
            onPressed: () {
              _getWidgetImage();
            },
            child: Text('generer QR code'),
          )
        ]),
      ],
    );
  }

  Widget pageConstruct(clubData, context) {
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      appBar: AppBar(
        title: Text('Réservation'),
      ),
      body: Container(
        child: Column(
          children: <Widget>[
            userBottomSection(clubData, context),
            _buttonGenerateQrCode(),
          ],
        ),
      ),
    );
  }
}