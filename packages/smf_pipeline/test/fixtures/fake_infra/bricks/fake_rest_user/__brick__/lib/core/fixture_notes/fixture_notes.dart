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
/// and cancels each call on its way when it is disposed of.
final class FixtureNotes extends ValueNotifier<FixtureNotesView> {
  /// Creates the state.
  FixtureNotes() : super(const FixtureNotesLoading());

  /// The calls on their way, each with a cancel of its own.
  final Set<RestCancel> _calls = {};

  /// The load on its way, which the next load replaces.
  RestCancel? _load;

  /// The notes that were added while the load on its way was out, of which its
  /// answer may know nothing.
  List<FixtureNote> _added = [];

  /// Loads the notes. An add on its way goes on, since the server may have
  /// done what it asked.
  Future<void> load() async {
    _load?.cancel();
    final cancel = _load = _newCall();
    final added = _added = [];
    value = const FixtureNotesLoading();
    try {
      final response = await appRest.get('notes', cancel: cancel);
      final notes = response.decoded(_notesOf);
      if (cancel.isCancelled) return;
      final ids = {for (final note in notes) note.id};
      value = FixtureNotesShown([
        ...notes,
        for (final note in added)
          if (!ids.contains(note.id)) note,
      ]);
    } on RestFailure catch (failure) {
      // An add that ended during the load shows what is newer.
      if (!cancel.isCancelled && added.isEmpty) {
        value = FixtureNotesFailed(failure.reason);
      }
    } finally {
      _calls.remove(cancel);
      if (identical(_load, cancel)) _load = null;
    }
  }

  /// Adds a note with [text], and shows it after the notes that are shown.
  Future<void> add(String text) async {
    final cancel = _newCall();
    try {
      final response = await appRest.post(
        'notes',
        json: {'text': text},
        cancel: cancel,
      );
      final note = response.decoded(FixtureNote.fromJson);
      if (cancel.isCancelled) return;
      if (_load != null) _added.add(note);
      final shown = value;
      value = FixtureNotesShown([
        if (shown is FixtureNotesShown) ...shown.notes,
        note,
      ]);
    } on RestFailure catch (failure) {
      if (!cancel.isCancelled) value = FixtureNotesFailed(failure.reason);
    } finally {
      _calls.remove(cancel);
    }
  }

  RestCancel _newCall() {
    final cancel = RestCancel();
    _calls.add(cancel);
    return cancel;
  }

  static List<FixtureNote> _notesOf(List<dynamic> json) => [
        for (final item in json)
          FixtureNote.fromJson(item as Map<String, dynamic>),
      ];

  @override
  void dispose() {
    for (final call in _calls) {
      call.cancel();
    }
    super.dispose();
  }
}
