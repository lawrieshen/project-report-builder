package com.projectreportbuilder.cloud;

public final class ReportException extends RuntimeException {
    public enum Code { UNAUTHENTICATED, NOT_FOUND, INVALID_REPORT, REVISION_CONFLICT }
    private final Code code;

    public ReportException(Code code, String message) {
        super(message);
        this.code = code;
    }

    public Code code() { return code; }
}
