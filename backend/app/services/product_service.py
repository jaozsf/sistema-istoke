import io
import base64
import qrcode
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.product_repository import ProductRepository
from app.repositories.log_repository import LogRepository
from app.models.product import Product
from app.schemas.product_stock import ProductCreate, ProductUpdate, ProductOut


class ProductService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = ProductRepository(db)
        self.log_repo = LogRepository(db)

    async def list(self, company_id: str, skip: int = 0, limit: int = 100):
        return await self.repo.get_by_company(company_id, skip, limit)

    async def search(self, company_id: str, q: str):
        return await self.repo.search(company_id, q)

    async def get(self, product_id: str, company_id: str) -> Product:
        product = await self.repo.get_by_id(product_id)
        if not product or product.company_id != company_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Produto não encontrado.")
        return product

    async def create(self, data: ProductCreate, company_id: str, user_id: str) -> Product:
        # SKU único por empresa
        existing = await self.repo.get_by_sku(data.sku, company_id)
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"SKU '{data.sku}' já cadastrado.")

        product = Product(**data.model_dump(), company_id=company_id)
        product = await self.repo.create(product)

        # Gera QR Code automaticamente
        qr_payload = f"STOCKIQ:{company_id}:{product.id}:{product.sku}"
        product.qr_code = qr_payload
        await self.db.flush()

        await self.log_repo.record(
            action="product.create", user_id=user_id, company_id=company_id,
            entity="product", entity_id=product.id, detail={"sku": product.sku, "name": product.name}
        )
        return product

    async def update(self, product_id: str, data: ProductUpdate, company_id: str, user_id: str) -> Product:
        product = await self.get(product_id, company_id)
        product = await self.repo.update(product, data.model_dump(exclude_none=True))
        await self.log_repo.record(
            action="product.update", user_id=user_id, company_id=company_id,
            entity="product", entity_id=product_id,
        )
        return product

    async def delete(self, product_id: str, company_id: str, user_id: str) -> None:
        product = await self.get(product_id, company_id)
        await self.repo.delete(product)
        await self.log_repo.record(
            action="product.delete", user_id=user_id, company_id=company_id,
            entity="product", entity_id=product_id,
        )

    async def get_qr_image(self, product_id: str, company_id: str) -> str:
        """Gera imagem QR Code em base64 PNG."""
        product = await self.get(product_id, company_id)
        if not product.qr_code:
            raise HTTPException(status_code=404, detail="QR Code não gerado para este produto.")

        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(product.qr_code)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        b64 = base64.b64encode(buffer.getvalue()).decode()
        return f"data:image/png;base64,{b64}"

    async def get_by_qr(self, qr_payload: str, company_id: str) -> Product:
        product = await self.repo.get_by_qr(qr_payload)
        if not product or product.company_id != company_id:
            raise HTTPException(status_code=404, detail="Produto não encontrado pelo QR Code.")
        return product
