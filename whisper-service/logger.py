"""
Logging configuration for Whisper service
Simplified version for standalone operation
"""

import logging
import os
from logging.handlers import RotatingFileHandler
from typing import Optional


def get_logger(name: str = "whisper-service") -> logging.Logger:
    """Get configured logger instance"""
    
    # Create logger
    logger = logging.getLogger(name)
    
    # Don't add handlers if they already exist (avoid duplicate logs)
    if logger.handlers:
        return logger
    
    # Set log level from environment
    log_level = os.getenv("LOG_LEVEL", "INFO").upper()
    logger.setLevel(getattr(logging, log_level))
    
    # Create console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logger.level)
    
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    console_handler.setFormatter(formatter)
    
    # Add handler to logger
    logger.addHandler(console_handler)

    # Rotating file handler (10 MB x 5 = ~50 MB cap)
    log_file = os.getenv("WHISPER_LOG_FILE", "/app/logs/whisper-service.log")
    file_handler = RotatingFileHandler(
        log_file, maxBytes=10_000_000, backupCount=5
    )
    file_handler.setLevel(logger.level)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    return logger