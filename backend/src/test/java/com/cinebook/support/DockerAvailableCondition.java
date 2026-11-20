package com.cinebook.support;

import org.junit.jupiter.api.extension.ConditionEvaluationResult;
import org.junit.jupiter.api.extension.ExecutionCondition;
import org.junit.jupiter.api.extension.ExtensionContext;
import org.testcontainers.DockerClientFactory;

/**
 * Lets integration tests be skipped on a developer machine without Docker, but never on CI:
 * there the test runs and fails loudly, so a green build always means the DB tests really ran.
 */
public class DockerAvailableCondition implements ExecutionCondition {

    @Override
    public ConditionEvaluationResult evaluateExecutionCondition(ExtensionContext context) {
        if ("true".equalsIgnoreCase(System.getenv("CI"))) {
            return ConditionEvaluationResult.enabled("CI=true: integration tests must run");
        }
        if (DockerClientFactory.instance().isDockerAvailable()) {
            return ConditionEvaluationResult.enabled("Docker is available");
        }
        return ConditionEvaluationResult.disabled("Docker is not available (set CI=true to fail instead of skipping)");
    }
}
