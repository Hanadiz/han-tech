from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
import uvicorn
from app.core.config import get_settings
from app.core.logging import setup_logging
from app.api.v1 import auth, services, subscriptions, payments, tickets, users
from app.core.middleware import RateLimitMiddleware, RequestIDMiddleware, LoggingMiddleware

settings = get_settings()

# Setup logging
setup_logging(settings.LOG_LEVEL)

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    docs_url="/api/docs" if settings.DEBUG else None,
    redoc_url="/api/redoc" if settings.DEBUG else None,
)

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["*"]  # Configure appropriately
)

app.add_middleware(RequestIDMiddleware)
app.add_middleware(LoggingMiddleware)
app.add_middleware(RateLimitMiddleware)

# Include routers
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(services.router, prefix="/api/v1/services", tags=["Services"])
app.include_router(subscriptions.router, prefix="/api/v1/subscriptions", tags=["Subscriptions"])
app.include_router(payments.router, prefix="/api/v1/payments", tags=["Payments"])
app.include_router(tickets.router, prefix="/api/v1/tickets", tags=["Tickets"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": settings.APP_NAME}

@app.get("/")
async def root():
    return {
        "message": f"Welcome to {settings.APP_NAME} API",
        "version": settings.APP_VERSION,
        "environment": settings.APP_ENV
    }

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        workers=settings.WORKERS,
        log_level=settings.LOG_LEVEL.lower()
    )