"""
qr_labels.py — Folha de etiquetas QR Code (um por produto), pronta pra
imprimir, recortar e colar em cada caixa.
"""
from __future__ import annotations
import io
import qrcode

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib.enums import TA_CENTER
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image

C_PRIMARY = colors.HexColor("#534AB7")
C_MUTED   = colors.HexColor("#666664")
C_BORDER  = colors.HexColor("#E8E6DE")

COLUMNS = 3
LABEL_QR_SIZE = 3.2 * cm


def _qr_image_flowable(payload: str) -> Image:
    qr = qrcode.QRCode(version=1, box_size=6, border=2)
    qr.add_data(payload)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    return Image(buf, width=LABEL_QR_SIZE, height=LABEL_QR_SIZE)


def generate_qr_labels_pdf(products: list) -> bytes:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer, pagesize=A4,
        topMargin=1.2 * cm, bottomMargin=1.2 * cm,
        leftMargin=1 * cm, rightMargin=1 * cm,
    )

    base = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "labelTitle", parent=base["Normal"], fontName="Helvetica-Bold",
        fontSize=22, leading=28, textColor=C_PRIMARY, alignment=TA_CENTER,
        spaceBefore=8, spaceAfter=6,
    )
    name_style = ParagraphStyle(
        "labelName", parent=base["Normal"], fontName="Helvetica-Bold",
        fontSize=9, alignment=TA_CENTER, spaceBefore=4,
    )
    sku_style = ParagraphStyle(
        "labelSku", parent=base["Normal"], fontName="Helvetica",
        fontSize=7.5, textColor=C_MUTED, alignment=TA_CENTER,
    )

    story = [
        Paragraph("StockIQ", title_style),
        Paragraph("Etiquetas QR Code — escaneie para movimentar estoque", sku_style),
        Spacer(1, 12),
    ]

    cells = []
    for p in products:
        cell = [
            _qr_image_flowable(p.qr_code),
            Paragraph(p.name, name_style),
            Paragraph(f"SKU: {p.sku}", sku_style),
        ]
        cells.append(cell)

    if not cells:
        story.append(Paragraph("Nenhum produto ativo com QR Code gerado.", sku_style))
    else:
        # Preenche linhas de COLUMNS em COLUMNS, completando com célula vazia
        rows = []
        for i in range(0, len(cells), COLUMNS):
            row = cells[i:i + COLUMNS]
            while len(row) < COLUMNS:
                row.append("")
            rows.append(row)

        col_width = (A4[0] - 2 * cm) / COLUMNS
        table = Table(rows, colWidths=[col_width] * COLUMNS, rowHeights=None)
        table.setStyle(TableStyle([
            ("ALIGN",  (0, 0), (-1, -1), "CENTER"),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("GRID",   (0, 0), (-1, -1), 0.5, C_BORDER),
            ("TOPPADDING",    (0, 0), (-1, -1), 10),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ]))
        story.append(table)

    doc.build(story)
    return buffer.getvalue()
