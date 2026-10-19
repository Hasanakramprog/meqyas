class CircularDependencyException implements Exception {
  final List<String> cyclePath;

  CircularDependencyException(this.cyclePath);

  @override
  String toString() => 'Circular dependency detected in formula variables: ${cyclePath.join(' -> ')}';
}

class DependencyGraph {
  final Map<String, Set<String>> _adj = {}; // node -> nodes that depend on it
  final Map<String, Set<String>> _deps = {}; // node -> nodes it depends on
  final Set<String> _nodes = {};

  void addNode(String node) {
    _nodes.add(node);
    _adj.putIfAbsent(node, () => {});
    _deps.putIfAbsent(node, () => {});
  }

  /// Adds a dependency: [node] depends on [dependsOnNode]
  void addDependency({required String node, required String dependsOnNode}) {
    addNode(node);
    addNode(dependsOnNode);
    _deps[node]!.add(dependsOnNode);
    _adj[dependsOnNode]!.add(node);
  }

  /// Returns nodes sorted in topological order (evaluable first).
  /// Throws [CircularDependencyException] if a cycle is present.
  List<String> topologicalSort() {
    // Detect cycles using DFS with 3 states (0: unvisited, 1: visiting, 2: visited)
    final state = <String, int>{};
    final path = <String>[];

    for (final node in _nodes) {
      state[node] = 0;
    }

    void dfs(String u) {
      state[u] = 1; // visiting
      path.add(u);

      for (final v in _deps[u] ?? const <String>{}) {
        if (!_nodes.contains(v)) {
          // External variable (e.g. 'W', 'H', 'sashCount'), not a computed dependency node
          continue;
        }
        if (state[v] == 1) {
          // Cycle found!
          final cycleStart = path.indexOf(v);
          final cycle = [...path.sublist(cycleStart), v];
          throw CircularDependencyException(cycle);
        }
        if (state[v] == 0) {
          dfs(v);
        }
      }

      path.removeLast();
      state[u] = 2; // visited
    }

    for (final node in _nodes) {
      if (state[node] == 0) {
        dfs(node);
      }
    }

    // Kahn's algorithm for linear ordering
    final inDegree = <String, int>{};
    for (final node in _nodes) {
      inDegree[node] = _deps[node]!.where(_nodes.contains).length;
    }

    final queue = <String>[];
    for (final node in _nodes) {
      if (inDegree[node] == 0) {
        queue.add(node);
      }
    }

    final result = <String>[];
    while (queue.isNotEmpty) {
      final u = queue.removeAt(0);
      result.add(u);

      for (final v in _adj[u] ?? const <String>{}) {
        inDegree[v] = inDegree[v]! - 1;
        if (inDegree[v] == 0) {
          queue.add(v);
        }
      }
    }

    if (result.length != _nodes.length) {
      throw CircularDependencyException(const ['Cycle in remaining components']);
    }

    return result;
  }
}
