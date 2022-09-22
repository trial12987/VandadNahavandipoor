// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'extensions.dart';
import 'package:async/async.dart' show StreamGroup;

@immutable
class Person {
  final String name;
  final int age;
  const Person({
    required this.name,
    required this.age,
  });

  Person.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        age = json['age'] as int;

  @override
  String toString() => 'Person(name: $name, age: $age)';
}

const peopleUrl = 'http://127.0.0.1:5500/vandad/lib/apis/people';
const people1Url = '${peopleUrl}1.json';
const people2Url = '${peopleUrl}2.json';

Future<Iterable<Person>> parseJson(String url) => HttpClient()
    .getUrl(Uri.parse(url))
    .then((req) => req.close())
    .then((response) => response.transform(utf8.decoder).join())
    .then((jsonString) => json.decode(jsonString) as List<dynamic>)
    .then((json) => json.map((map) => Person.fromJson(map)));

//4.1---parseJson------------------------------------------------------------------

void test4_1() async {
  final persons = await parseJson(people1Url);
  persons.log();
}

//4.2---Future.wait - Multiple Futures - If you want the results-------------------

void test4_2() async {
  final persons = await Future.wait([
    parseJson(people1Url),
    parseJson(people2Url),
  ]);
  persons.log();
}

//4.3---Catch Error Extensions-----------------------------------------------------

void test4_3() async {
  final persons = await Future.wait([
    //If you want to error check individually
    parseJson(people1Url).emptyOnErrorOnFuture(),
    parseJson(people2Url).emptyOnErrorOnFuture(),
  ]).emptyOnError(); //Custom extension on extensions.dart = catchError((_, __) => List<Iterable<Person>>.empty())
  persons.log();
}

//4.4---Future.forEach - Multiple Futures - If you dont care about the results-----

void test4_4() async {
  final result = await Future.forEach(
    //returns null if when elements have been processed succesfully
    Iterable.generate(2, (i) => '$peopleUrl${i + 1}.json'),
    parseJson,
  ).catchError((_, __) => -1);
  //(_,__) ignore the error and stacktrace by giving _ and __ unused var names, and return -1

  if (result != null) {
    'Error Occured!'.log();
  }
}

//4.5---Async Generators - Generates Streams - You dont have to use a stream controller---

//Stream<Person>            |------P------P-------P--------------------P----
//Stream<Iterable<Person>>  |------[P1,P2,..]------[P3]-------[P4,P5,P6]-----
Stream<Iterable<Person>> getPersons3() async* {
  for (final url in Iterable.generate(2, (i) => '$peopleUrl${i + 1}.json')) {
    1.log();
    yield await parseJson(url);
    4.log();
  }
}

void test4_5() async {
  await for (final persons in getPersons3()) {
    2.log();
    persons.log();
    3.log();
  }
}

//4.6---Multiple Api List - Depending on the result of another---------------------

//a Mixin that can return a list of things
mixin ListOfThingsAPI<T> {
  Future<Iterable<T>> get(String url) => HttpClient()
      .getUrl(Uri.parse(url))
      .then((req) => req.close())
      .then((resp) => resp.transform(utf8.decoder).join())
      .then((str) => json.decode(str) as List<dynamic>)
      .then((list) => list.cast());
}

class GetApiEndPoints with ListOfThingsAPI<String> {}

class GetPeople with ListOfThingsAPI<Map<String, dynamic>> {
  Future<Iterable<Person>> getPeople(String url) => get(url).then(
        (jsons) => jsons.map(
          (json) => Person.fromJson(json),
        ),
      );
}

void test4_6() async {
  final people = await GetApiEndPoints()
      .get('http://127.0.0.1:5500/vandad/lib/apis/apis.json')
      .then(
        (urls) => Future.wait(
          urls.map(
            (url) => GetPeople().getPeople(url),
          ),
        ),
      );
  people.log();
}

//4.7---Async Expand - Every value generated, can generate another Stream----------

void test4_7() async {
  //You can make an async API call on a Async Stream
  await for (final people in Stream.periodic(const Duration(seconds: 3))
      .asyncExpand((_) => GetPeople().getPeople(people1Url).asStream())) {
    people.log();
  }
}

//4.8---Stream Transformation - Transform values of your stream to other values----
const names = ['foo', 'bar', 'baz'];

class UpperCaseSink implements EventSink<String> {
  final EventSink<String> _sink;
  const UpperCaseSink(this._sink);

  @override
  void add(String event) => _sink.add(event.toUpperCase());

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _sink.addError(error, stackTrace);
  }

  @override
  void close() {
    _sink.close();
  }
}

class StreamTransformUpperCaseString
    extends StreamTransformerBase<String, String> {
  @override
  Stream<String> bind(Stream<String> stream) =>
      Stream<String>.eventTransformed(stream, (sink) => UpperCaseSink(sink));
}

void test4_8() async {
  await for (final name in Stream.periodic(
          const Duration(seconds: 1), (_) => names.getRandomElement())
      .transform(StreamTransformUpperCaseString())) {
    name.log();
  }
}

//3.1---Isolates-------------------------------------------------------------------

Future<Iterable<Person>> getPersons() async {
  final rp = ReceivePort();
  await Isolate.spawn(_getPersons, rp.sendPort);
  return await rp.first;
}

void _getPersons(SendPort sp) async {
  final persons = await parseJson(people1Url);
  Isolate.exit(sp, persons);
}

void test3_1() async {
  final persons = getPersons();
  persons.log();
}

//3.2---Stream Of Isolates---------------------------------------------------------

Stream<String> getMessages() {
  final rp = ReceivePort();
  return Isolate.spawn(_getMessages, rp.sendPort)
      .asStream() // Future<Isolate> to Stream<Isolate>
      .asyncExpand((_) => rp) // Change the data type to ReceivePorts data type
      .takeWhile((element) =>
          element is String) //eliminate the null, Isolate.exit(sp,null);
      .cast();
}

void _getMessages(SendPort sp) async {
  await for (final now in Stream.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now().toIso8601String(),
  ).take(10)) {
    sp.send(now);
  }
  Isolate.exit(sp); // = Isolate.exit(sp, null);
}

void test3_2() async {
  await for (final msg in getMessages()) {
    msg.log();
  }
}

//3.3---Parse Multiple JSONs-------------------------------------------------------
@immutable
class PersonsRequest {
  final ReceivePort receivePort;
  final Uri uri;
  const PersonsRequest(this.receivePort, this.uri);

  static Iterable<PersonsRequest> all() sync* {
    for (final i in Iterable.generate(3, (i) => i)) {
      yield PersonsRequest(
        ReceivePort(),
        Uri.parse('$peopleUrl${i + 1}.json'),
      );
    }
  }
}

@immutable
class Request {
  final SendPort sendPort;
  final Uri uri;
  const Request(this.sendPort, this.uri);

  Request.from(PersonsRequest request)
      : sendPort = request.receivePort.sendPort,
        uri = request.uri;
}

Stream<Iterable<Person>> getPersons2() {
  final streams = PersonsRequest.all().map((req) =>
      Isolate.spawn(_getPersons2, Request.from(req))
          .asStream()
          .asyncExpand((_) => req.receivePort)
          .takeWhile((element) => element is Iterable<Person>)
          .cast());

  return StreamGroup.merge(streams).cast();
}

void _getPersons2(Request request) async {
  final persons = await parseJson(request.uri.toString());
  Isolate.exit(request.sendPort, persons);
}

void test3_3() async {
  await for (final msg in getPersons2()) {
    msg.log();
  }
}

//---------------------------------------------------------------------------------

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    "start".log();
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            TextButton(
                onPressed: () async {
                  test3_3();
                },
                child: const Text('Press Me'))
          ],
        ),
      ),
    );
  }
}
