from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.core.database import get_db
from app.core.security import get_current_user, require_manager, require_admin
from app.services.product_service import ProductService
from app.schemas.product_stock import ProductCreate, ProductUpdate, ProductOut

router = APIRouter(prefix="/products", tags=["Produtos"])


@router.get("", response_model=List[ProductOut], summary="Listar produtos da empresa")
async def list_products(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    q: str = Query(None, description="Busca por nome, SKU ou categoria"),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = ProductService(db)
    if q:
        return await svc.search(current_user.company_id, q)
    return await svc.list(current_user.company_id, skip, limit)


@router.post("", response_model=ProductOut, status_code=201, summary="Criar produto")
async def create_product(
    data: ProductCreate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_manager),
):
    svc = ProductService(db)
    return await svc.create(data, current_user.company_id, current_user.id)


@router.get("/{product_id}", response_model=ProductOut)
async def get_product(
    product_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = ProductService(db)
    return await svc.get(product_id, current_user.company_id)


@router.patch("/{product_id}", response_model=ProductOut)
async def update_product(
    product_id: str,
    data: ProductUpdate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_manager),
):
    svc = ProductService(db)
    return await svc.update(product_id, data, current_user.company_id, current_user.id)


@router.delete("/{product_id}", status_code=204)
async def delete_product(
    product_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = ProductService(db)
    await svc.delete(product_id, current_user.company_id, current_user.id)


@router.get("/{product_id}/qr", summary="Retorna imagem QR Code em base64")
async def get_qr(
    product_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = ProductService(db)
    b64 = await svc.get_qr_image(product_id, current_user.company_id)
    return {"product_id": product_id, "qr_image": b64}


@router.get("/scan/{qr_payload}", response_model=ProductOut, summary="Busca produto pelo QR Code")
async def scan_qr(
    qr_payload: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = ProductService(db)
    return await svc.get_by_qr(qr_payload, current_user.company_id)
