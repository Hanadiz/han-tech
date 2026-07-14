import logging
import sys
import json
from datetime import datetime
from logging.handlers import RotatingFileHandler
import os

def setup_logging(level="INFO"):
    log_level = getattr(logging, level.upper())
    
    # Create logger
    logger = logging.getLogger()
    logger.setLevel(log_level)
    
    # Remove existing handlers
    logger.handlers = []
    
    # Format for JSON logging (for production)
    class JSONFormatter(logging.Formatter):
        def format(self, record):
            log_data = {
                "timestamp": datetime.utcnow().isoformat(),
                "level": record.levelname,
                "message": record.getMessage(),
                "module": record.module,
                "function": record.funcName,
                "line": record.lineno
            }
            
            if hasattr(record, 'request_id'):
                log_data["request_id"] = record.request_id
                
            if record.exc_info:
                log_data["exception"] = self.formatException(record.exc_info)
                
            return json.dumps(log_data)
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    if os.getenv("APP_ENV") == "production":
        console_handler.setFormatter(JSONFormatter())
    else:
        console_handler.setFormatter(
            logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
        )
    logger.addHandler(console_handler)
    
    # File handler for persistent logs
    if os.getenv("LOG_FILE"):
        file_handler = RotatingFileHandler(
            os.getenv("LOG_FILE"),
            maxBytes=10485760,  # 10MB
            backupCount=5
        )
        file_handler.setFormatter(JSONFormatter())
        logger.addHandler(file_handler)
    
    # Reduce noise from third-party libraries
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy").setLevel(logging.WARNING)
    
    return logger