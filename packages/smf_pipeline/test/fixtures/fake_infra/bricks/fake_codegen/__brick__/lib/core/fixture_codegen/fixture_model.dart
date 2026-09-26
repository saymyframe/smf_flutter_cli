import 'package:json_annotation/json_annotation.dart';

part 'fixture_model.g.dart';

/// A model whose JSON code build_runner generates.
@JsonSerializable()
final class FixtureModel {
  /// Creates the model.
  const FixtureModel(this.name);

  /// Creates the model from [json].
  factory FixtureModel.fromJson(Map<String, dynamic> json) =>
      _$FixtureModelFromJson(json);

  /// The name.
  final String name;

  /// The model as JSON.
  Map<String, dynamic> toJson() => _$FixtureModelToJson(this);
}
