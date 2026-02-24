"""
Duplicate/build-slide page remover for PDFs.

For each PDF in Slides/sec1 (recursively):
  - Render each page to an image.
  - Compare the current page with the previous page:
      * Top region  = first 10% of page height
      * Bottom region = last 5% of page height
    If BOTH regions are pixel-identical between the two pages,
    the *previous* page is considered a build-step duplicate and is removed.
  - Save the cleaned PDF into "Slides/sec1 Processed/<same relative path>".
  - Copy all non-PDF files to the processed folder, preserving structure.
"""

import argparse
import os
import sys
import shutil
from pathlib import Path

import fitz  # PyMuPDF


# ── Configuration ────────────────────────────────────────────────────────────
TOP_FRAC = 0.10   # first 10 % of the page height
# BOT_FRAC = 0.05   # last  5 % of the page height
DPI = 150          # render resolution (higher = more accurate but slower)


def render_region(page: fitz.Page, clip: fitz.Rect) -> bytes:
    """Render a clipped region of a page and return raw pixel bytes."""
    mat = fitz.Matrix(DPI / 72, DPI / 72)
    pix = page.get_pixmap(matrix=mat, clip=clip)
    data = pix.samples  # raw pixel bytes
    pix = None
    return data


def regions_match(page_a: fitz.Page, page_b: fitz.Page) -> bool:
    """
    Return True if the top 10 % and bottom 5 % of two pages are
    pixel-identical at the configured DPI.
    """
    rect_a = page_a.rect
    rect_b = page_b.rect

    # Pages with different dimensions are never duplicates
    if (rect_a.width, rect_a.height) != (rect_b.width, rect_b.height):
        return False

    h = rect_a.height

    # ── Top region ──────────────────────────────────────────────────────
    top_clip = fitz.Rect(rect_a.x0, rect_a.y0,
                         rect_a.x1, rect_a.y0 + h * TOP_FRAC)
    if render_region(page_a, top_clip) != render_region(page_b, top_clip):
        return False

    # ── Bottom region (disabled) ────────────────────────────────────────
    # bot_clip = fitz.Rect(rect_a.x0, rect_a.y1 - h * BOT_FRAC,
    #                      rect_a.x1, rect_a.y1)
    # if render_region(page_a, bot_clip) != render_region(page_b, bot_clip):
    #     return False

    return True


def process_pdf(src_path: Path, dst_path: Path) -> int:
    """
    Open *src_path*, remove build-step duplicate pages, and write to *dst_path*.
    Returns the number of pages removed.
    """
    doc = fitz.open(src_path)
    n_pages = len(doc)

    if n_pages <= 1:
        # Nothing to deduplicate
        dst_path.parent.mkdir(parents=True, exist_ok=True)
        doc.save(str(dst_path))
        doc.close()
        return 0

    pages_to_delete: list[int] = []

    # Walk forward; compare page[i] with page[i-1].
    # If they match, mark page[i-1] for deletion (the earlier build step).
    for i in range(1, n_pages):
        prev_page = doc[i - 1]
        curr_page = doc[i]
        if regions_match(prev_page, curr_page):
            pages_to_delete.append(i - 1)

    # Handle consecutive duplicates: if page 0,1,2 are all builds,
    # pages 0 and 1 would both be marked — that's fine; we keep the last.
    # Remove duplicates and sort descending so indices stay valid.
    pages_to_delete = sorted(set(pages_to_delete), reverse=True)

    for pg in pages_to_delete:
        doc.delete_page(pg)

    dst_path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(dst_path), garbage=4, deflate=True)
    doc.close()

    return len(pages_to_delete)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove build-step duplicate pages from PDFs."
    )
    parser.add_argument("src", help="Source directory containing PDFs")
    parser.add_argument("dst", help="Destination directory for processed output")
    args = parser.parse_args()

    SRC_DIR = Path(args.src).resolve()
    DST_DIR = Path(args.dst).resolve()

    if not SRC_DIR.exists():
        print(f"Source directory not found: {SRC_DIR}")
        sys.exit(1)

    print(f"Source : {SRC_DIR}")
    print(f"Dest   : {DST_DIR}")
    print()

    total_removed = 0
    pdf_count = 0
    other_count = 0

    for root, _dirs, files in os.walk(SRC_DIR):
        root_path = Path(root)
        rel = root_path.relative_to(SRC_DIR)

        for fname in files:
            src_file = root_path / fname
            dst_file = DST_DIR / rel / fname

            if fname.lower().endswith(".pdf"):
                pdf_count += 1
                print(f"Processing: {rel / fname} ", end="... ", flush=True)
                removed = process_pdf(src_file, dst_file)
                total_removed += removed
                print(f"removed {removed} pages")
            else:
                # Copy non-PDF files as-is
                dst_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src_file, dst_file)
                other_count += 1
                print(f"Copied    : {rel / fname}")

    print()
    print(f"Done — {pdf_count} PDFs processed, "
          f"{total_removed} total duplicate pages removed, "
          f"{other_count} other files copied.")


if __name__ == "__main__":
    main()
