from fastapi import APIRouter, HTTPException
from app.models.order import OrderCreate, OrderResponse
from app.services import firestore as db

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", response_model=OrderResponse, status_code=201)
def place_order(payload: OrderCreate):
    product = db.get_product(payload.product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.get("status") != "ready":
        raise HTTPException(status_code=400, detail="Product video is not ready yet")

    unit_price = product["price"]
    order_data = {
        **payload.model_dump(),
        "product_title": product["title"],
        "unit_price": unit_price,
        "total_price": round(unit_price * payload.quantity, 2),
    }
    order = db.create_order(order_data)
    return OrderResponse(**order)


@router.get("", response_model=list[OrderResponse])
def list_orders():
    return [OrderResponse(**o) for o in db.list_orders()]


@router.get("/{order_id}", response_model=OrderResponse)
def get_order(order_id: str):
    order = db.get_order(order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return OrderResponse(**order)
