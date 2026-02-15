#!/bin/bash
# filepath: /blog/articles/tools/skopeo_copy_image.sh
#
# Script to copy container images from a source registry to a destination 
# registry using skopeo while preserving digests and all tags.
#
# Usage: ./skopeo_copy_image.sh <source-image>

# Exit on error, undefined variable reference, and prevent errors in pipelines from being masked
set -euo pipefail

# Configuration
AUTH_FILE="${HOME}/.docker/config.json"  # Use HOME variable instead of hardcoded path
DEST_REGISTRY="registry.poc4.ecocenter.fr:8443/init/oc-mirror-metadata"

# Validate input
if [ $# -lt 1 ]; then
    echo "Error: Missing source image argument" >&2
    echo "Usage: $(basename "$0") <source-image>" >&2
    exit 1
fi

SOURCE_IMAGE="$1"

# Extract the image path without registry prefix
if [[ "$SOURCE_IMAGE" == *"/"* ]]; then
    IMAGE_PATH=$(echo "$SOURCE_IMAGE" | cut -d/ -f2-)
else
    echo "Error: Invalid image format. Expected format: registry/image-path" >&2
    exit 1
fi

# Check if auth file exists
if [ ! -f "$AUTH_FILE" ]; then
    echo "Warning: Auth file not found at $AUTH_FILE" >&2
    echo "Authentication might fail if credentials are required" >&2
fi

# Display and execute the copy operation
echo "Copying image from $SOURCE_IMAGE to $DEST_REGISTRY/$IMAGE_PATH..."

skopeo copy \
    --all \
    --preserve-digests \
    --authfile "${AUTH_FILE}" \
    "docker://$SOURCE_IMAGE" \
    "docker://$DEST_REGISTRY/$IMAGE_PATH"

exit_code=$?
if [ $exit_code -eq 0 ]; then
    echo "Image copied successfully!"
else
    echo "Error: Image copy failed with exit code $exit_code" >&2
fi

exit $exit_code
