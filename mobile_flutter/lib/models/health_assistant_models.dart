class HealthAssistantRequest {
  HealthAssistantRequest({
    required this.query,
    this.model = 'gemini-2.5-flash',
  });

  final String query;
  final String model;

  Map<String, dynamic> toJson() {
    return {
      'query': query.trim(),
      'model': model,
    };
  }
}

class HealthAssistantResponse {
  HealthAssistantResponse({
    required this.status,
    required this.response,
    required this.model,
  });

  final String status;
  final String response;
  final String model;

  factory HealthAssistantResponse.fromJson(Map<String, dynamic> json) {
    return HealthAssistantResponse(
      status: (json['status'] ?? '').toString(),
      response: (json['response'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
    );
  }
}
