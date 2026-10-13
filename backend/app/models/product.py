from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class ProductCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=200)
    description: str = Field(..., min_length=10)
    price: float = Field(..., gt=0)
    tags: list[str] = Field(default_factory=list)
    artisan_name: str = Field(..., min_length=1, max_length=100)
    video_object_key: str


class ProductResponse(BaseModel):
    id: str
    title: str
    description: str
    price: float
    tags: list[str]
    artisan_name: str
    video_object_key: str
    status: str  # processing | ready | failed
    hls_manifest_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    created_at: str

    model_config = {"from_attributes": True}
