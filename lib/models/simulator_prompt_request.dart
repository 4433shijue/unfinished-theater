enum SimulatorPromptGenerationMode {
  fullSimulator,
  worldStage,
}

class SimulatorPromptGenerationRequest {
  const SimulatorPromptGenerationRequest({
    required this.roleName,
    required this.simulatorIdea,
    this.shortDescription = '',
    this.styleHint = '',
    this.extraConstraints = '',
    this.uploadedDocumentText = '',
    this.mode = SimulatorPromptGenerationMode.fullSimulator,
  });

  final String roleName;
  final String simulatorIdea;
  final String shortDescription;
  final String styleHint;
  final String extraConstraints;
  final String uploadedDocumentText;
  final SimulatorPromptGenerationMode mode;
}

class SimulatorPromptGenerationResult {
  const SimulatorPromptGenerationResult({
    required this.prompt,
    required this.description,
    required this.openingMessage,
    this.name = '',
  });

  final String prompt;
  final String description;
  final String openingMessage;

  /// 生成器给出的模拟器名称（JSON 模式直接来自 name 字段，
  /// 老式标签解析兜底时可能为空）。
  final String name;
}
