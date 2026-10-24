from __future__ import annotations  # métodos chamados "list" sombreiam o builtin nas anotações
from datetime import datetime, timezone
from decimal import Decimal
from fastapi import HTTPException
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.timezone import br_day_range
from app.models.box_standard import BoxStandard
from app.models.partner import Distributor, Customer
from app.models.order import Order, OrderItem, OrderEvent, OrderStatus
from app.models.product import Product
from app.models.user import User
from app.models.finance import Finance, FinanceType
from app.repositories.base_repository import BaseRepository
from app.repositories.branch_repository import BranchRepository
from app.repositories.log_repository import LogRepository
from app.schemas.logistics import (
    BoxStandardIn, DistributorIn, CustomerIn,
    OrderCreate, OrderUpdate, OrderTransition, OrderOut,
)
from app.schemas.product_stock import MovementCreate
from app.services.finance_service import ART_SURCHARGE, BORDER_SURCHARGE
from app.services.stock_service import StockService, _is_ecologico

S = OrderStatus
MANAGER_ROLES = ("admin", "manager")

# Quem pode levar o pedido de uma etapa pra outra (admin/manager podem tudo).
# Cancelamento é tratado à parte em _can_transition.
TRANSITIONS: dict[str, dict[str, tuple[str, ...]]] = {
    S.enviado.value:      {S.em_producao.value: ("production",), S.em_separacao.value: ("shipping",)},
    S.em_producao.value:  {S.em_separacao.value: ("production",)},
    S.em_separacao.value: {S.conferido.value: ("shipping",)},
    # Reabrir conferência (achou divergência depois de conferir)
    S.conferido.value:    {S.despachado.value: ("shipping",), S.em_separacao.value: ("shipping",)},
}
FINAL = (S.despachado.value, S.cancelado.value)

STATUS_LABEL = {
    S.enviado.value: "Enviado à fábrica",
    S.em_producao.value: "Em produção",
    S.em_separacao.value: "Em separação",
    S.conferido.value: "Conferido",
    S.despachado.value: "Despachado",
    S.cancelado.value: "Cancelado",
}


# ─── Padrão de caixa ──────────────────────────────────────────────────────────

class BoxStandardService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.log_repo = LogRepository(db)

    async def list(self, company_id: str) -> list[BoxStandard]:
        result = await self.db.execute(select(BoxStandard).where(BoxStandard.company_id == company_id))
        return list(result.scalars().all())

    async def upsert(self, product_id: str, data: BoxStandardIn, company_id: str, user_id: str) -> BoxStandard:
        product = await self.db.get(Product, product_id)
        if not product or product.company_id != company_id:
            raise HTTPException(status_code=404, detail="Produto não encontrado.")

        result = await self.db.execute(select(BoxStandard).where(BoxStandard.product_id == product_id))
        box = result.scalar_one_or_none()
        if box is None:
            box = BoxStandard(product_id=product_id, company_id=company_id, **data.model_dump())
            self.db.add(box)
        else:
            # model_dump completo (não exclude_none): admin pode limpar medida
            for k, v in data.model_dump().items():
                setattr(box, k, v)
        await self.db.flush()
        await self.db.refresh(box)
        await self.log_repo.record(
            action="box_standard.upsert", user_id=user_id, company_id=company_id,
            entity="product", entity_id=product_id, detail={"units_per_box": data.units_per_box},
        )
        return box

    async def delete(self, product_id: str, company_id: str, user_id: str) -> None:
        result = await self.db.execute(
            select(BoxStandard).where(BoxStandard.product_id == product_id, BoxStandard.company_id == company_id)
        )
        box = result.scalar_one_or_none()
        if not box:
            raise HTTPException(status_code=404, detail="Padrão de caixa não encontrado.")
        await self.db.delete(box)
        await self.db.flush()
        await self.log_repo.record(
            action="box_standard.delete", user_id=user_id, company_id=company_id,
            entity="product", entity_id=product_id,
        )


# ─── Distribuidoras ───────────────────────────────────────────────────────────

class DistributorService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = BaseRepository(Distributor, db)
        self.log_repo = LogRepository(db)

    async def list(self, company_id: str, include_inactive: bool = False) -> list[Distributor]:
        q = select(Distributor).where(Distributor.company_id == company_id)
        if not include_inactive:
            q = q.where(Distributor.is_active == True)  # noqa: E712
        result = await self.db.execute(q.order_by(Distributor.name))
        return list(result.scalars().all())

    async def get(self, distributor_id: str, company_id: str) -> Distributor:
        d = await self.repo.get_by_id(distributor_id)
        if not d or d.company_id != company_id:
            raise HTTPException(status_code=404, detail="Distribuidora não encontrada.")
        return d

    async def create(self, data: DistributorIn, company_id: str, user_id: str) -> Distributor:
        d = await self.repo.create(Distributor(**data.model_dump(), company_id=company_id))
        await self.log_repo.record(
            action="distributor.create", user_id=user_id, company_id=company_id,
            entity="distributor", entity_id=d.id, detail={"name": d.name},
        )
        return d

    async def update(self, distributor_id: str, data: DistributorIn, company_id: str, user_id: str) -> Distributor:
        d = await self.get(distributor_id, company_id)
        for k, v in data.model_dump().items():
            setattr(d, k, v)
        await self.db.flush()
        await self.db.refresh(d)
        await self.log_repo.record(
            action="distributor.update", user_id=user_id, company_id=company_id,
            entity="distributor", entity_id=d.id,
        )
        return d

    async def deactivate(self, distributor_id: str, company_id: str, user_id: str) -> None:
        # Soft delete: pedido antigo continua apontando pra ela
        d = await self.get(distributor_id, company_id)
        d.is_active = False
        await self.db.flush()
        await self.log_repo.record(
            action="distributor.deactivate", user_id=user_id, company_id=company_id,
            entity="distributor", entity_id=d.id,
        )


# ─── Clientes ─────────────────────────────────────────────────────────────────

class CustomerService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = BaseRepository(Customer, db)

    async def list(self, company_id: str, q: str | None = None, seller_id: str | None = None) -> list[Customer]:
        query = select(Customer).where(Customer.company_id == company_id, Customer.is_active == True)  # noqa: E712
        if seller_id:
            query = query.where(Customer.seller_id == seller_id)
        if q:
            like = f"%{q.lower()}%"
            query = query.where(or_(
                func.lower(Customer.name).like(like),
                func.lower(func.coalesce(Customer.city, "")).like(like),
                func.coalesce(Customer.document, "").like(like),
            ))
        result = await self.db.execute(query.order_by(Customer.name).limit(500))
        return list(result.scalars().all())

    async def get(self, customer_id: str, company_id: str) -> Customer:
        c = await self.repo.get_by_id(customer_id)
        if not c or c.company_id != company_id:
            raise HTTPException(status_code=404, detail="Cliente não encontrado.")
        return c

    async def create(self, data: CustomerIn, company_id: str, user: User) -> Customer:
        return await self.repo.create(Customer(**data.model_dump(), company_id=company_id, seller_id=user.id))

    async def update(self, customer_id: str, data: CustomerIn, user: User) -> Customer:
        c = await self.get(customer_id, user.company_id)
        if user.role not in MANAGER_ROLES and c.seller_id != user.id:
            raise HTTPException(status_code=403, detail="Cliente de outro vendedor.")
        for k, v in data.model_dump().items():
            setattr(c, k, v)
        await self.db.flush()
        await self.db.refresh(c)
        return c

    async def deactivate(self, customer_id: str, company_id: str) -> None:
        c = await self.get(customer_id, company_id)
        c.is_active = False
        await self.db.flush()


# ─── Pedidos ──────────────────────────────────────────────────────────────────

class OrderService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.log_repo = LogRepository(db)

    # ── Consultas ─────────────────────────────────────────────────────────────

    async def list(self, user: User, status: str | None = None, limit: int = 100) -> list[OrderOut]:
        q = select(Order).where(Order.company_id == user.company_id)
        if user.role == "seller":
            q = q.where(Order.seller_id == user.id)
        if status == "abertos":
            q = q.where(Order.status.not_in(FINAL))
        elif status:
            q = q.where(Order.status.in_(status.split(",")))
        result = await self.db.execute(q.order_by(Order.created_at.desc()).limit(limit))
        return await self._to_out_many(list(result.scalars().all()), user)

    async def summary(self, user: User) -> dict:
        q = select(Order.status, func.count()).where(Order.company_id == user.company_id)
        if user.role == "seller":
            q = q.where(Order.seller_id == user.id)
        rows = (await self.db.execute(q.group_by(Order.status))).all()
        counts = {s.value: 0 for s in OrderStatus}
        counts.update({status: n for status, n in rows})

        start, end = br_day_range(1)
        dq = select(func.count()).where(
            Order.company_id == user.company_id,
            Order.status == S.despachado.value,
            Order.dispatched_at >= start, Order.dispatched_at < end,
        )
        if user.role == "seller":
            dq = dq.where(Order.seller_id == user.id)
        dispatched_today = (await self.db.execute(dq)).scalar_one()
        open_total = sum(n for s, n in counts.items() if s not in FINAL)
        return {"counts": counts, "open_total": open_total, "dispatched_today": dispatched_today}

    async def get(self, order_id: str, user: User) -> Order:
        order = await self.db.get(Order, order_id)
        if not order or order.company_id != user.company_id:
            raise HTTPException(status_code=404, detail="Pedido não encontrado.")
        if user.role == "seller" and order.seller_id != user.id:
            raise HTTPException(status_code=404, detail="Pedido não encontrado.")
        return order

    async def get_out(self, order_id: str, user: User) -> OrderOut:
        return (await self._to_out_many([await self.get(order_id, user)], user))[0]

    # ── Criação ───────────────────────────────────────────────────────────────

    async def create(self, data: OrderCreate, user: User) -> OrderOut:
        company_id = user.company_id
        customer = await CustomerService(self.db).get(data.customer_id, company_id)
        if data.distributor_id:
            dist = await DistributorService(self.db).get(data.distributor_id, company_id)
            if not dist.is_active:
                raise HTTPException(status_code=422, detail="Distribuidora inativa.")

        branch_id = data.branch_id or user.branch_id
        if not branch_id:
            branches = await BranchRepository(self.db).get_by_company(company_id)
            if not branches:
                raise HTTPException(status_code=422, detail="Empresa sem filial cadastrada.")
            branch_id = branches[0].id
        branch = await BranchRepository(self.db).get_by_id(branch_id)
        if not branch or branch.company_id != company_id:
            raise HTTPException(status_code=404, detail="Filial não encontrada.")

        product_ids = [i.product_id for i in data.items]
        products = {
            p.id: p for p in (await self.db.execute(
                select(Product).where(Product.id.in_(product_ids), Product.company_id == company_id)
            )).scalars().all()
        }
        boxes = {
            b.product_id: b for b in (await self.db.execute(
                select(BoxStandard).where(BoxStandard.product_id.in_(product_ids))
            )).scalars().all()
        }

        number = (await self.db.execute(
            select(func.coalesce(func.max(Order.number), 0)).where(Order.company_id == company_id)
        )).scalar_one() + 1

        order = Order(
            number=number, status=S.enviado.value, company_id=company_id, branch_id=branch_id,
            customer_id=customer.id, seller_id=user.id, distributor_id=data.distributor_id,
            notes=data.notes,
        )
        for pos, item in enumerate(data.items):
            product = products.get(item.product_id)
            if not product or not product.is_active:
                raise HTTPException(status_code=404, detail="Produto do pedido não encontrado.")
            box = boxes.get(product.id)
            if not box:
                raise HTTPException(
                    status_code=422,
                    detail=f"{product.name} não tem padrão de caixa. Peça ao admin cadastrar em Gestão > Padrões de caixa.",
                )
            if item.has_border and _is_ecologico(product):
                raise HTTPException(
                    status_code=422,
                    detail=f"{product.name}: copo ecológico não pode ter borda — o material derrete no processo.",
                )
            order.items.append(OrderItem(
                product_id=product.id, position=pos,
                quantity_boxes=item.quantity_boxes, units_per_box=box.units_per_box,
                box_weight_kg=box.weight_kg, unit_price=product.sale_price,
                product_name=product.name, product_sku=product.sku,
                has_art=item.has_art, has_border=item.has_border, art_notes=item.art_notes,
            ))
        order.events.append(OrderEvent(
            from_status=None, to_status=S.enviado.value, user_id=user.id, user_name=user.full_name,
            note="Pedido criado pelo vendedor",
        ))
        self.db.add(order)
        await self.db.flush()

        await self.log_repo.record(
            action="order.create", user_id=user.id, company_id=company_id, branch_id=branch_id,
            entity="order", entity_id=order.id, detail={"number": number, "customer": customer.name},
        )
        next_role = "production" if order.needs_production else "shipping"
        await self._notify_roles(
            company_id, (next_role,),
            f"Novo pedido #{number:04d}",
            f"{customer.name} — {order.total_boxes} caixa(s)"
            + (" com personalização" if order.needs_production else ""),
            order.id,
        )
        return await self.get_out(order.id, user)

    async def update(self, order_id: str, data: OrderUpdate, user: User) -> OrderOut:
        order = await self.get(order_id, user)
        if user.role not in MANAGER_ROLES + ("seller",):
            raise HTTPException(status_code=403, detail="Só vendedor ou gerente altera o pedido.")
        if order.status in FINAL:
            raise HTTPException(status_code=409, detail="Pedido já finalizado.")
        if data.distributor_id is not None:
            if data.distributor_id:
                dist = await DistributorService(self.db).get(data.distributor_id, user.company_id)
                if not dist.is_active:
                    raise HTTPException(status_code=422, detail="Distribuidora inativa.")
            order.distributor_id = data.distributor_id or None
        if data.notes is not None:
            order.notes = data.notes
        await self.db.flush()
        return await self.get_out(order.id, user)

    # ── Conferência ───────────────────────────────────────────────────────────

    async def check_item(self, order_id: str, item_id: str, checked_boxes: int, user: User) -> OrderOut:
        if user.role not in MANAGER_ROLES + ("shipping",):
            raise HTTPException(status_code=403, detail="Só a expedição confere caixas.")
        order = await self.get(order_id, user)
        if order.status != S.em_separacao.value:
            raise HTTPException(status_code=409, detail="Conferência só durante a separação.")
        item = next((i for i in order.items if i.id == item_id), None)
        if not item:
            raise HTTPException(status_code=404, detail="Item não encontrado.")
        if checked_boxes > item.quantity_boxes:
            raise HTTPException(
                status_code=422,
                detail=f"Contou {checked_boxes} caixas, mas o pedido tem {item.quantity_boxes}. Confira de novo.",
            )
        item.checked_boxes = checked_boxes
        await self.db.flush()
        return await self.get_out(order.id, user)

    # ── Fluxo ─────────────────────────────────────────────────────────────────

    def allowed_transitions(self, order: Order, user: User) -> list[str]:
        return [s.value for s in OrderStatus if self._can_transition(order, s.value, user) is None]

    def _can_transition(self, order: Order, to: str, user: User) -> str | None:
        """None = pode; string = motivo de não poder."""
        frm = order.status
        if frm in FINAL:
            return "Pedido já finalizado."
        if to == S.cancelado.value:
            if user.role in MANAGER_ROLES:
                return None
            if user.role == "seller" and order.seller_id == user.id and frm == S.enviado.value:
                return None
            return "Só gerente cancela pedido em andamento."
        roles = TRANSITIONS.get(frm, {}).get(to)
        if roles is None:
            return f"Não dá pra ir de '{STATUS_LABEL[frm]}' para '{STATUS_LABEL.get(to, to)}'."
        if user.role not in MANAGER_ROLES and user.role not in roles:
            return "Seu setor não executa essa etapa."
        if frm == S.enviado.value and to == S.em_producao.value and not order.needs_production:
            return "Pedido sem arte/borda vai direto pra separação."
        if frm == S.enviado.value and to == S.em_separacao.value and order.needs_production:
            return "Pedido com arte/borda passa pela produção primeiro."
        if to == S.conferido.value and any(not i.is_checked for i in order.items):
            return "Confira todas as caixas antes de finalizar a conferência."
        if to == S.despachado.value and not order.distributor_id:
            return "Escolha a distribuidora antes de despachar."
        return None

    async def transition(self, order_id: str, data: OrderTransition, user: User) -> OrderOut:
        order = await self.get(order_id, user)
        reason = self._can_transition(order, data.to_status, user)
        if reason:
            raise HTTPException(status_code=409, detail=reason)

        frm, to = order.status, data.to_status

        # Copo sai da prateleira assim que o pedido deixa "enviado" (arte e
        # borda só são feitas depois de tirar do estoque).
        if frm == S.enviado.value and to in (S.em_producao.value, S.em_separacao.value) and not order.stock_deducted:
            await self._deduct_stock(order, user)
        if to == S.cancelado.value and order.stock_deducted:
            await self._return_stock(order, user)
        if frm == S.conferido.value and to == S.em_separacao.value:
            for i in order.items:
                i.checked_boxes = 0
        if to == S.conferido.value and data.note:
            order.check_notes = data.note
        if to == S.despachado.value:
            order.dispatched_at = datetime.now(timezone.utc)
            order.invoice_number = data.invoice_number or order.invoice_number
            order.tracking_code = data.tracking_code or order.tracking_code

        order.status = to
        order.events.append(OrderEvent(
            from_status=frm, to_status=to, note=data.note, user_id=user.id, user_name=user.full_name,
        ))
        await self.db.flush()

        await self.log_repo.record(
            action=f"order.{to}", user_id=user.id, company_id=user.company_id, branch_id=order.branch_id,
            entity="order", entity_id=order.id, detail={"from": frm, "to": to, "number": order.number},
        )
        await self._notify_transition(order, to)
        return await self.get_out(order.id, user)

    # ── Estoque ───────────────────────────────────────────────────────────────

    async def _deduct_stock(self, order: Order, user: User) -> None:
        customer = await self.db.get(Customer, order.customer_id)
        stock = StockService(self.db)
        for item in order.items:
            # register_movement valida saldo (422 se faltar) e lança receita/custo
            await stock.register_movement(
                MovementCreate(
                    type="saida", quantity=item.quantity_units,
                    product_id=item.product_id, branch_id=order.branch_id,
                    notes=f"Pedido #{order.number:04d} — {customer.name if customer else ''} "
                          f"({item.quantity_boxes} cx x {item.units_per_box})",
                    has_art=item.has_art, has_border=item.has_border,
                ),
                order.company_id, user.id,
            )
        order.stock_deducted = True

    async def _return_stock(self, order: Order, user: User) -> None:
        stock = StockService(self.db)
        for item in order.items:
            await stock.register_movement(
                MovementCreate(
                    type="entrada", quantity=item.quantity_units,
                    product_id=item.product_id, branch_id=order.branch_id,
                    notes=f"Estorno — pedido #{order.number:04d} cancelado",
                ),
                order.company_id, user.id,
            )
            # Estorno do financeiro lançado na saída (mesma conta de record_sale)
            extra_r = (ART_SURCHARGE["revenue"] if item.has_art else 0) + (BORDER_SURCHARGE["revenue"] if item.has_border else 0)
            extra_c = (ART_SURCHARGE["cost"] if item.has_art else 0) + (BORDER_SURCHARGE["cost"] if item.has_border else 0)
            product = await self.db.get(Product, item.product_id)
            cost = product.cost_price if product else Decimal(0)
            for ftype, amount in (
                (FinanceType.receita, (item.unit_price + extra_r) * item.quantity_units),
                (FinanceType.custo, (cost + extra_c) * item.quantity_units),
            ):
                self.db.add(Finance(
                    type=ftype, amount=-amount,
                    description=f"Estorno pedido #{order.number:04d}: {item.product_name} x{item.quantity_units}",
                    reference_id=order.id, company_id=order.company_id,
                    branch_id=order.branch_id, user_id=user.id,
                ))
        order.stock_deducted = False
        await self.db.flush()

    # ── Notificações ──────────────────────────────────────────────────────────

    async def _notify_transition(self, order: Order, to: str) -> None:
        title = f"Pedido #{order.number:04d}: {STATUS_LABEL[to]}"
        if to == S.em_separacao.value:
            await self._notify_roles(order.company_id, ("shipping",), title, "Pronto pra separar as caixas.", order.id)
        elif to == S.despachado.value and order.seller_id:
            await self._notify_users([order.seller_id], title, "Carga entregue à distribuidora.", order.id)
        elif to == S.cancelado.value:
            await self._notify_roles(order.company_id, ("shipping", "production"), title, "Pedido cancelado.", order.id)
            if order.seller_id:
                await self._notify_users([order.seller_id], title, "Pedido cancelado.", order.id)

    async def _notify_roles(self, company_id: str, roles: tuple[str, ...], title: str, body: str, order_id: str):
        result = await self.db.execute(
            select(User.id).where(User.company_id == company_id, User.is_active == True, User.role.in_(roles))  # noqa: E712
        )
        await self._notify_users(list(result.scalars().all()), title, body, order_id)

    async def _notify_users(self, user_ids: list[str], title: str, body: str, order_id: str):
        if not user_ids:
            return
        from app.repositories.device_token_repository import DeviceTokenRepository
        from app.services.push_service import send_push
        tokens = await DeviceTokenRepository(self.db).get_tokens_for_users(user_ids)
        if tokens:
            await send_push(tokens, title=title, body=body, data={"route": f"/orders/{order_id}"})

    # ── Serialização ──────────────────────────────────────────────────────────

    async def _to_out_many(self, orders: list[Order], user: User) -> list[OrderOut]:
        if not orders:
            return []
        cust_ids = {o.customer_id for o in orders}
        user_ids = {o.seller_id for o in orders if o.seller_id}
        dist_ids = {o.distributor_id for o in orders if o.distributor_id}
        customers = {c.id: c for c in (await self.db.execute(select(Customer).where(Customer.id.in_(cust_ids)))).scalars()}
        sellers = {u.id: u for u in (await self.db.execute(select(User).where(User.id.in_(user_ids)))).scalars()} if user_ids else {}
        dists = {d.id: d for d in (await self.db.execute(select(Distributor).where(Distributor.id.in_(dist_ids)))).scalars()} if dist_ids else {}

        out = []
        for o in orders:
            dto = OrderOut.model_validate(o)
            c = customers.get(o.customer_id)
            dto.customer_name = c.name if c else None
            dto.customer_city = (f"{c.city}/{c.state}" if c.state else c.city) if c and c.city else None
            dto.seller_name = sellers[o.seller_id].full_name if o.seller_id in sellers else None
            dto.distributor_name = dists[o.distributor_id].name if o.distributor_id in dists else None
            dto.allowed_transitions = self.allowed_transitions(o, user)
            out.append(dto)
        return out
