package com.projectreportbuilder.cloud;

import java.util.Map;
import java.util.UUID;

public interface ReportAssetStorage {
    record Transfer(String url, Map<String, String> headers) { }
    Transfer upload(String owner, UUID report, ReportAsset asset);
    Transfer download(String owner, UUID report, ReportAsset asset);
    void verify(String owner, UUID report, ReportAsset asset);
}
