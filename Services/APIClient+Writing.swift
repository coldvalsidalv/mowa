import Foundation

// MARK: - Writing grading (Phase 2)

extension APIClient {
    func gradeWriting(task: WritingTask, text: String, lang: String) async throws -> WritingFeedback {
        let body: [String: Any] = [
            "task_id": task.taskId,
            "task": [
                "type": task.type,
                "prompt": task.prompt,
                "required_points": task.requiredPoints,
                "min_words": task.minWords,
                "max_words": task.maxWords,
            ],
            "text": text,
            "feedback_lang": lang,
        ]
        // LLM grading is slow (several seconds); the default 15s timeout is too tight.
        return try await post(path: "/api/v1/writing/grade", body: body, timeout: 60)
    }
}
