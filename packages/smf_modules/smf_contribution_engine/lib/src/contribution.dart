import 'package:dart_style/dart_style.dart';

abstract class Contribution {
  const Contribution({required this.file});

  final String file;

  Future<String> apply(String original);

  DartFormatter get dartFormater => DartFormatter(
    languageVersion: DartFormatter.latestShortStyleLanguageVersion,
  );
}
