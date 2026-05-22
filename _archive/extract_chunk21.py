import json

data = {
  "nodes": [
    {"id": "build_and_deploy_instructions", "label": "FPGA Build & Deployment Instructions", "file_type": "document", "source_file": "docs/BUILD_AND_DEPLOY.txt", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "cheatsheet", "label": "Cheatsheet", "file_type": "document", "source_file": "docs/CHEATSHEET.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "collection_instructions", "label": "Collection Instructions", "file_type": "document", "source_file": "docs/COLLECTION_INSTRUCTIONS.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "completion_report", "label": "Completion Report", "file_type": "document", "source_file": "docs/COMPLETION_REPORT.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "fingerprint_sensor", "label": "Fingerprint Sensor README", "file_type": "document", "source_file": "docs/FINGERPRINT_SENSOR_README.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "implementation", "label": "Implementation Details", "file_type": "document", "source_file": "docs/IMPLEMENTATION.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "quick_start", "label": "Quick Start Guide", "file_type": "document", "source_file": "docs/QUICK_START.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "readme2", "label": "Readme2", "file_type": "document", "source_file": "docs/Readme2.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "readme_simple", "label": "README Simple", "file_type": "document", "source_file": "docs/README_SIMPLE.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "streamline_summary", "label": "Streamline Summary", "file_type": "document", "source_file": "docs/STREAMLINE_SUMMARY.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "test_results", "label": "Test Results", "file_type": "document", "source_file": "docs/TEST_RESULTS.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None},
    {"id": "workflow", "label": "Workflow", "file_type": "document", "source_file": "docs/WORKFLOW.md", "source_location": None, "source_url": None, "captured_at": None, "author": None, "contributor": None}
  ],
  "edges": [
    {"source": "build_and_deploy_instructions", "target": "collection_instructions", "relation": "conceptually_related_to", "confidence": "INFERRED", "confidence_score": 0.85, "source_file": "docs/BUILD_AND_DEPLOY.txt", "source_location": None, "weight": 1.0},
    {"source": "implementation", "target": "test_results", "relation": "conceptually_related_to", "confidence": "INFERRED", "confidence_score": 0.85, "source_file": "docs/IMPLEMENTATION.md", "source_location": None, "weight": 1.0}
  ],
  "hyperedges": [],
  "input_tokens": 1500,
  "output_tokens": 500
}

with open('graphify-out/.graphify_chunk_21.json', 'w') as f:
    json.dump(data, f, indent=2)
