import uuid
from datetime import datetime, timezone
from typing import Optional
from google.cloud import firestore
from app.config import settings

_client: Optional[firestore.Client] = None


def get_db() -> firestore.Client:
    global _client
    if _client is None:
        _client = firestore.Client(project=settings.gcp_project_id)
    return _client


# ── Products ──────────────────────────────────────────────────────────────────

def product_title_exists(title: str) -> bool:
    db = get_db()
    docs = (
        db.collection("products")
        .where(filter=firestore.FieldFilter("title_lower", "==", title.lower()))
        .limit(1)
        .stream()
    )
    return any(True for _ in docs)


def create_product(data: dict) -> dict:
    db = get_db()
    product_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    doc = {
        "id": product_id,
        "created_at": now,
        "status": "processing",
        **data,
        "tags": [t.lower() for t in data.get("tags", [])],
        "title_lower": data.get("title", "").lower(),
    }
    db.collection("products").document(product_id).set(doc)
    return doc


def get_product(product_id: str) -> Optional[dict]:
    db = get_db()
    doc = db.collection("products").document(product_id).get()
    return doc.to_dict() if doc.exists else None


def update_product(product_id: str, updates: dict) -> None:
    db = get_db()
    db.collection("products").document(product_id).update(updates)


def search_products(query: str = "", tags: list[str] | None = None) -> list[dict]:
    db = get_db()
    docs = db.collection("products").limit(50).stream()
    results = sorted([d.to_dict() for d in docs], key=lambda p: p.get("created_at", ""), reverse=True)

    # Case-insensitive tag filter (Firestore array-contains-any is exact-match only)
    if tags:
        tag_lower = {t.lower() for t in tags}
        results = [
            p for p in results
            if any(t.lower() in tag_lower for t in p.get("tags", []))
        ]

    # Case-insensitive keyword filter across title, description, artisan_name, and tags
    if query:
        q = query.lower()
        results = [
            p for p in results
            if q in p.get("title", "").lower()
            or q in p.get("description", "").lower()
            or q in p.get("artisan_name", "").lower()
            or any(q in t.lower() for t in p.get("tags", []))
        ]
    return results


# ── Orders ────────────────────────────────────────────────────────────────────

def create_order(data: dict) -> dict:
    db = get_db()
    order_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    doc = {
        "id": order_id,
        "created_at": now,
        "status": "confirmed",
        **data,
    }
    db.collection("orders").document(order_id).set(doc)
    return doc


def list_orders() -> list[dict]:
    db = get_db()
    docs = db.collection("orders").limit(100).stream()
    return sorted([d.to_dict() for d in docs], key=lambda o: o.get("created_at", ""), reverse=True)


def get_order(order_id: str) -> Optional[dict]:
    db = get_db()
    doc = db.collection("orders").document(order_id).get()
    return doc.to_dict() if doc.exists else None
