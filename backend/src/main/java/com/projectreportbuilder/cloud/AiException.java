package com.projectreportbuilder.cloud;

/** Expose stable error codes without including prompts, credentials, or provider responses. */
public final class AiException extends RuntimeException {
    public enum Code {
        AI_DISABLED, INVALID_INPUT, DAILY_QUOTA, BUDGET_EXHAUSTED, REQUEST_PENDING,
        REQUEST_MISMATCH, REQUEST_EXPIRED, PROVIDER_RATE_LIMITED, PROVIDER_TIMEOUT,
        INVALID_OUTPUT, AI_UNAVAILABLE
    }

    private final Code code;
    public AiException(Code code) { super(code.name()); this.code = code; }
    public Code code() { return code; }
}
