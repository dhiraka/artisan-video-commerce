from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.routers import products, orders, videos

app = FastAPI(
    title="Artisan Video-Commerce API",
    description="Backend for the Artisan Video-Commerce Platform",
    version="1.0.0",
)

origins = [o.strip() for o in settings.cors_origins.split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(products.router, prefix="/api")
app.include_router(orders.router, prefix="/api")
app.include_router(videos.router, prefix="/api")


@app.get("/health")
def health_check():
    return {"status": "ok"}
