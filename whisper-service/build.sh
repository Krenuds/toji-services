#!/bin/bash
set -e

echo "Building Whisper Service Docker Image..."

# Build the image
docker build -t whisper-service:latest .

echo "Build complete! To run the service:"
echo "  docker-compose up -d"
echo ""
echo "To test GPU support:"
echo "  docker run --gpus all whisper-service:latest python -c \"import torch; print(f'CUDA available: {torch.cuda.is_available()}')\""
echo ""
echo "To view logs:"
echo "  docker-compose logs -f whisper-service"