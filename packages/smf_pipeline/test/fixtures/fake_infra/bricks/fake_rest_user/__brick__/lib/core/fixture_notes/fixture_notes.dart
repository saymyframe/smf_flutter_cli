import 'package:flutter/foundation.dart';

import '../rest/app_rest.dart';

/// A note of the server of the fixture.
final class FixtureNote {
  /// Creates the note.
  const FixtureNote({required this.id, required this.text});

  /// The note in the JSON of the server.
  factory FixtureNote.fromJson(Map<String, dynamic> json) => FixtureNote(
        id: json['id'] as int,
        text: json['text'] as String,
      );

  /// The id that the server gave the note.
  final int id;

  /// The text of the note.
  final String text;
}

/// What a screen shows of the notes.
sealed class FixtureNotesView {
  const FixtureNotesView();
}

/// The notes are on their way.
final class FixtureNotesLoading extends FixtureNotesView {
  /// Creates the view.
  const FixtureNotesLoading();
}

/// The notes that the server has.
final class FixtureNotesShown extends FixtureNotesView {
  /// Creates the view.
  const FixtureNotesShown(this.notes);

  /// The notes.
  final List<FixtureNote> notes;
}

/// A call failed, for which a screen shows a text of its own.
final class FixtureNotesFailed extends FixtureNotesView {
  /// Creates the view.
  const FixtureNotesFailed(this.reason);

  /// Why the call failed.
  final RestFailureReason reason;
}

/// The state of a screen with the notes of a server, as the state of a screen
/// uses the REST client of the app: it knows the role and no provider of it,
/// and cancels its call when it is disposed of.
final class FixtureNotes extends ValueNotifier<FixtureNotesView> {
  /// Creates the state.
  FixtureNotes() : super(const FixtureNotesLoading());

  RestCancel? _load;

  /// Loads the notes.
  Future<void> load() async {
    _load?.cancel();
    final cancel = _load = RestCancel();
    value = const FixtureNotesLoading();
    await _ending(cancel, () async {
      final response = await appRest.get('notes', cancel: cancel);
      return FixtureNotesShown(response.decoded(_notesOf));
    });
  }

  /// Adds a note with [text], and shows it after the notes that are shown.
  Future<void> add(String text) async {
    final before = value;
    final cancel = _load = RestCancel();
    await _ending(cancel, () async {
      final response = await appRest.post(
        'notes',
        json: {'text': text},
        cancel: cancel,
      );
      return FixtureNotesShown([
        if (before is FixtureNotesShown) ...before.notes,
        response.decoded(FixtureNote.fromJson),
      ]);
    });
  }

  /// Shows what [call] ends with, unless [cancel] ended it.
  Future<void> _ending(
    RestCancel cancel,
    Future<FixtureNotesView> Function() call,
  ) async {
    FixtureNotesView view;
    try {
      view = await call();
    } on RestFailure catch (failure) {
      view = FixtureNotesFailed(failure.reason);
    }
    if (!cancel.isCancelled) value = view;
  }

  static List<FixtureNote> _notesOf(List<dynamic> json) => [
        for (final item in json)
          FixtureNote.fromJson(item as Map<String, dynamic>),
      ];

  @override
  void dispose() {
    _load?.cancel();
    super.dispose();
  }
}
