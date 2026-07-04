import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/features/notes/domain/note_graph.dart';
import 'package:memento/features/notes/domain/note_tree_node.dart';

void main() {
  late Directory vaultRoot;
  late FileSystemNoteRepository repository;

  setUp(() async {
    vaultRoot = await Directory.systemTemp.createTemp('memento_graph_test');
    repository = FileSystemNoteRepository(vaultRoot);
  });

  tearDown(() async {
    if (vaultRoot.existsSync()) {
      await vaultRoot.delete(recursive: true);
    }
  });

  test('every note becomes a node, even with no links', () async {
    await repository.createNote('', 'Первая');
    await repository.createNote('', 'Вторая');
    final List<NoteTreeNode> tree = await repository.loadTree();

    final NoteGraph graph = await buildNoteGraph(repository, tree);

    expect(graph.nodes.map((n) => n.title).toSet(), {'Первая', 'Вторая'});
    expect(graph.edges, isEmpty);
  });

  test('a wiki-link creates an edge between the two notes', () async {
    await repository.createNote('', 'Первая');
    await repository.createNote('', 'Вторая');
    await repository.writeNote('Первая', 'Смотри [[Вторая]].');
    final List<NoteTreeNode> tree = await repository.loadTree();

    final NoteGraph graph = await buildNoteGraph(repository, tree);

    expect(graph.edges, hasLength(1));
    expect(graph.edges.single.fromId, 'Первая');
    expect(graph.edges.single.toId, 'Вторая');
  });

  test('a link in both directions collapses to a single edge', () async {
    await repository.createNote('', 'Первая');
    await repository.createNote('', 'Вторая');
    await repository.writeNote('Первая', '[[Вторая]]');
    await repository.writeNote('Вторая', '[[Первая]]');
    final List<NoteTreeNode> tree = await repository.loadTree();

    final NoteGraph graph = await buildNoteGraph(repository, tree);

    expect(graph.edges, hasLength(1));
    expect(graph.connectionCount('Первая'), 1);
    expect(graph.connectionCount('Вторая'), 1);
  });

  test('a link to a nonexistent title is dropped', () async {
    await repository.createNote('', 'Первая');
    await repository.writeNote('Первая', '[[Не существует]]');
    final List<NoteTreeNode> tree = await repository.loadTree();

    final NoteGraph graph = await buildNoteGraph(repository, tree);

    expect(graph.edges, isEmpty);
  });

  test('a self-link is dropped', () async {
    await repository.createNote('', 'Первая');
    await repository.writeNote('Первая', 'Смотри также [[Первая]].');
    final List<NoteTreeNode> tree = await repository.loadTree();

    final NoteGraph graph = await buildNoteGraph(repository, tree);

    expect(graph.edges, isEmpty);
  });

  test('links are matched case-insensitively', () async {
    await repository.createNote('', 'Архив');
    await repository.createNote('', 'Заметка');
    await repository.writeNote('Заметка', '[[АРХИВ]]');
    final List<NoteTreeNode> tree = await repository.loadTree();

    final NoteGraph graph = await buildNoteGraph(repository, tree);

    expect(graph.edges, hasLength(1));
  });
}
