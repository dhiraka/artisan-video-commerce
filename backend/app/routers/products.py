from fastapi import APIRouter, HTTPException, Query, status
from app.models.product import ProductCreate, ProductResponse
from app.services import firestore as db

router = APIRouter(prefix="/products", tags=["products"])


@router.get("/check-title")
def check_title(title: str = Query(..., min_length=1)):
    return {"exists": db.product_title_exists(title)}


@router.post("", response_model=ProductResponse, status_code=201)
def create_product(payload: ProductCreate):
    if db.product_title_exists(payload.title):
        raise HTTPException(status_code=409, detail="A product with this title already exists")
    data = payload.model_dump()
    product = db.create_product(data)
    return ProductResponse(**product)


@router.get("", response_model=list[ProductResponse])
def list_products(
    q: str = Query(default="", description="Keyword search"),
    tags: str = Query(default="", description="Comma-separated tag filter"),
):
    tag_list = [t.strip() for t in tags.split(",") if t.strip()] if tags else []
    results = db.search_products(query=q, tags=tag_list if tag_list else None)
    return [ProductResponse(**p) for p in results]


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(product_id: str):
    product = db.get_product(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return ProductResponse(**product)
