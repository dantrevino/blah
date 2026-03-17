enum AgentType { claude, codex, opencode }

enum SessionStatus { starting, running, idle, error, terminated }

class Session {
  final String id;
  final int number;
  final String name;
  final String repoPath;
  final String worktreePath;
  final String gitBranch;
  final AgentType agentType;
  final SessionStatus status;
  final String? instructions;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  Session({
    required this.id,
    required this.number,
    required this.name,
    required this.repoPath,
    required this.worktreePath,
    required this.gitBranch,
    required this.agentType,
    this.status = SessionStatus.starting,
    this.instructions,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now();

  Session copyWith({
    SessionStatus? status,
    String? name,
    DateTime? lastActiveAt,
  }) {
    return Session(
      id: id,
      number: number,
      name: name ?? this.name,
      repoPath: repoPath,
      worktreePath: worktreePath,
      gitBranch: gitBranch,
      agentType: agentType,
      status: status ?? this.status,
      instructions: instructions,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'repoPath': repoPath,
      'worktreePath': worktreePath,
      'gitBranch': gitBranch,
      'agentType': agentType.name,
      'status': status.name,
      'instructions': instructions,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      number: json['number'],
      name: json['name'],
      repoPath: json['repoPath'],
      worktreePath: json['worktreePath'],
      gitBranch: json['gitBranch'],
      agentType: AgentType.values.byName(json['agentType']),
      status: SessionStatus.values.byName(json['status']),
      instructions: json['instructions'],
      createdAt: DateTime.parse(json['createdAt']),
      lastActiveAt: DateTime.parse(json['lastActiveAt']),
    );
  }
}
