import logging
import pymupdf

logger = logging.getLogger(__name__)


def extract_text_from_pdf(pdf_bytes: bytes) -> str:
    """
    Extracts text from PDF file bytes using PyMuPDF.
    Returns cleaned, stripped text.
    """
    if not pdf_bytes:
        raise ValueError("Empty PDF file payload")

    try:
        doc = pymupdf.open(stream=pdf_bytes, filetype="pdf")
    except Exception as exc:
        logger.error(f"Failed to open PDF stream with PyMuPDF: {exc}")
        raise ValueError(f"Invalid or corrupted PDF file: {exc}")

    pages_text = []
    for page in doc:
        text = page.get_text("text")
        if text.strip():
            pages_text.append(text.strip())

    doc.close()

    full_text = "\n\n".join(pages_text).strip()
    if not full_text:
        raise ValueError("Could not extract any readable text from the provided PDF (file may be scanned or empty).")

    return full_text
