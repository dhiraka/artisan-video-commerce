from pydantic import BaseModel, Field, EmailStr
from typing import Optional


class OrderCreate(BaseModel):
    product_id: str
    buyer_name: str = Field(..., min_length=2, max_length=100)
    buyer_email: EmailStr
    quantity: int = Field(..., ge=1, le=100)
    shipping_address: str = Field(..., min_length=10)


class OrderResponse(BaseModel):
    id: str
    product_id: str
    product_title: str
    buyer_name: str
    buyer_email: str
    quantity: int
    unit_price: float
    total_price: float
    status: str  # confirmed
    created_at: str
