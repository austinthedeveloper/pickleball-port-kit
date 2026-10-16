#include <snes.h>
#include <string.h>
#include "hud.h"
#include "hud_tiles.h"
#include "ram_copy.h"
#include "render.h"

#define HUD_HFLIP 0x4000
#define HUD_VFLIP 0x8000
#define HUD_SPACE 32

/* Global so src/asm/hud_fill.asm can reach it. */
u16 g_hud_map[32 * HUD_ROWS];
/* Bit n: band n (rows 4n..4n+3) changed; global for hud_commit.asm. */
u8 hud_dirty;

/* Inputs for hud_fill (src/asm/hud_fill.asm). */
u16 hud_fill_index;
u16 hud_fill_count;
u16 hud_fill_value;
extern void hud_fill(void);


static void hud_mark(u8 row)
{
    hud_dirty |= (u8)(1 << (row >> 2));
}

void hud_initialize(void)
{
    hud_dirty = 0;
    hud_clear_rows(0, HUD_ROWS);
}

void hud_clear_rows(u8 first_row, u8 count)
{
    u8 row;

#ifdef HOST_TEST
    memset(&g_hud_map[(u16)first_row * 32], 0, (u16)count * 64);
#else
    hud_fill_index = (u16)first_row * 32;
    hud_fill_count = (u16)count * 32;
    hud_fill_value = HUD_TILE_CLEAR;
    hud_fill();
#endif
    for (row = first_row; row < first_row + count; row += HUD_BAND_ROWS)
        hud_mark(row);
    hud_mark(first_row + count - 1);
}

void hud_save_rows(u8 first_row, u8 count, u16 *out)
{
    RAM_COPY(out, &g_hud_map[(u16)first_row * 32], (u16)count * 64);
}

void hud_restore_rows(u8 first_row, u8 count, const u16 *in)
{
    u8 row;

    RAM_COPY(&g_hud_map[(u16)first_row * 32], in, (u16)count * 64);
    for (row = first_row; row < first_row + count; row += HUD_BAND_ROWS)
        hud_mark(row);
    hud_mark(first_row + count - 1);
}

void hud_fill_box(u8 col, u8 row, u8 width, u8 rows, u16 entry)
{
    u8 last = row + rows;

    for (; row < last; ++row) {
#ifdef HOST_TEST
        u8 i;

        for (i = 0; i < width; ++i)
            g_hud_map[(u16)row * 32 + col + i] = entry;
#else
        hud_fill_index = (u16)row * 32 + col;
        hud_fill_count = width;
        hud_fill_value = entry;
        hud_fill();
#endif
        hud_mark(row);
    }
}

void hud_tile(u8 col, u8 row, u16 entry)
{
    g_hud_map[(u16)row * 32 + col] = entry;
    hud_mark(row);
}

#ifndef HOST_TEST
/* Inputs for hud_text_write (src/asm/hud_text.asm, M4-UI-01). */
const char *hud_text_src;
u16 hud_text_index;
u16 hud_text_cols;
u16 hud_text_attr;
extern void hud_text_write(void);
#endif

void hud_text(u8 col, u8 row, u8 palette, const char *text)
{
#ifdef HOST_TEST
    u16 index = (u16)row * 32 + col;
    u8 c;

    while ((c = (u8)*text++) != 0 && col < 32) {
        if (c >= 'a' && c <= 'z')
            c -= 'a' - 'A';
        if (c < 32 || c > 95)
            c = '?';
        g_hud_map[index++] = hud_entry(c, palette);
        ++col;
    }
#else
    if (col < 32) {
        hud_text_src = text;
        hud_text_index = (u16)row * 32 + col;
        hud_text_cols = 32 - col;
        hud_text_attr = hud_entry(0, palette);
        hud_text_write();
    }
#endif
    hud_mark(row);
}

void hud_number(u8 col, u8 row, u8 palette, u8 value)
{
    if (value >= 10) {
        g_hud_map[(u16)row * 32 + col] = hud_entry('0' + value / 10, palette);
        ++col;
    }
    g_hud_map[(u16)row * 32 + col] = hud_entry('0' + value % 10, palette);
    hud_mark(row);
}

/* Edges as one assembly fill per row (hud_fill_box): a C loop over a wide
 * panel cost 816-tcc about 60 scanlines (ADR-026). */
void hud_panel(u8 col, u8 row, u8 inner_cols)
{
    u8 right = col + inner_cols + 1;
    u16 top = (u16)row * 32;
    u16 mid = top + 32;
    u16 bottom = mid + 32;

    hud_fill_box(col + 1, row, inner_cols, 1,
        hud_entry(HUD_TILE_PANEL_T, 0));
    hud_fill_box(col + 1, row + 1, inner_cols, 1, hud_entry(HUD_SPACE, 0));
    hud_fill_box(col + 1, row + 2, inner_cols, 1,
        hud_entry(HUD_TILE_PANEL_T, 0) | HUD_VFLIP);
    g_hud_map[top + col] = hud_entry(HUD_TILE_PANEL_TL, 0);
    g_hud_map[top + right] = hud_entry(HUD_TILE_PANEL_TL, 0) | HUD_HFLIP;
    g_hud_map[bottom + col] = hud_entry(HUD_TILE_PANEL_TL, 0) | HUD_VFLIP;
    g_hud_map[bottom + right] =
        hud_entry(HUD_TILE_PANEL_TL, 0) | HUD_HFLIP | HUD_VFLIP;
    g_hud_map[mid + col] = hud_entry(HUD_TILE_PANEL_L, 0);
    g_hud_map[mid + right] = hud_entry(HUD_TILE_PANEL_L, 0) | HUD_HFLIP;
}

/* A panel's border around inner_cols x inner_rows cells left clear, so a
 * layer under the HUD shows through (the close call, ADR-041). */
void hud_frame(u8 col, u8 row, u8 inner_cols, u8 inner_rows)
{
    u8 right = col + inner_cols + 1;
    u8 bottom = row + inner_rows + 1;
    u8 r;

    hud_fill_box(col + 1, row, inner_cols, 1,
        hud_entry(HUD_TILE_PANEL_T, 0));
    hud_fill_box(col + 1, row + 1, inner_cols, inner_rows, HUD_TILE_CLEAR);
    hud_fill_box(col + 1, bottom, inner_cols, 1,
        hud_entry(HUD_TILE_PANEL_T, 0) | HUD_VFLIP);
    g_hud_map[(u16)row * 32 + col] = hud_entry(HUD_TILE_PANEL_TL, 0);
    g_hud_map[(u16)row * 32 + right] =
        hud_entry(HUD_TILE_PANEL_TL, 0) | HUD_HFLIP;
    g_hud_map[(u16)bottom * 32 + col] =
        hud_entry(HUD_TILE_PANEL_TL, 0) | HUD_VFLIP;
    g_hud_map[(u16)bottom * 32 + right] =
        hud_entry(HUD_TILE_PANEL_TL, 0) | HUD_HFLIP | HUD_VFLIP;
    for (r = row + 1; r < bottom; ++r) {
        g_hud_map[(u16)r * 32 + col] = hud_entry(HUD_TILE_PANEL_L, 0);
        g_hud_map[(u16)r * 32 + right] =
            hud_entry(HUD_TILE_PANEL_L, 0) | HUD_HFLIP;
    }
}

/* Index into HUD_BIG_CHARS ("A-Z0-9'!") without searching. */
static s16 hud_big_index(u8 c)
{
    if (c >= 'A' && c <= 'Z')
        return c - 'A';
    if (c >= '0' && c <= '9')
        return 26 + (c - '0');
    if (c == '\'')
        return 36;
    if (c == '!')
        return 37;
    return -1;
}

u8 hud_big_width(const char *text)
{
    u8 n = 0;
    while (*text++)
        n += 2;
    return n;
}

void hud_big_text(u8 col, u8 row, u8 palette, const char *text)
{
    u16 top = (u16)row * 32;
    u16 tile;
    s16 index;
    u8 c;

    while ((c = (u8)*text++) != 0 && col < 31) {
        index = hud_big_index(c);
        if (index < 0) {
            g_hud_map[top + col] = HUD_TILE_CLEAR;
            g_hud_map[top + col + 1] = HUD_TILE_CLEAR;
            g_hud_map[top + 32 + col] = HUD_TILE_CLEAR;
            g_hud_map[top + 32 + col + 1] = HUD_TILE_CLEAR;
        } else {
            tile = HUD_TILE_BIG_BASE + (u16)index * 4;
            g_hud_map[top + col] = hud_entry(tile, palette);
            g_hud_map[top + col + 1] = hud_entry(tile + 1, palette);
            g_hud_map[top + 32 + col] = hud_entry(tile + 2, palette);
            g_hud_map[top + 32 + col + 1] = hud_entry(tile + 3, palette);
        }
        col += 2;
    }
    hud_mark(row);
    hud_mark(row + 1);
}

void hud_center_big(u8 row, u8 palette, const char *text)
{
    hud_big_text((u8)(16 - hud_big_width(text) / 2), row, palette, text);
}

/* Centered three-row panel with a B button glyph replacing '@'. */
static u8 hud_prompt_col(const char *text, u8 *len)
{
    const char *p = text;

    *len = 0;
    while (*p++)
        ++*len;
    return (u8)(16 - (*len + 2) / 2);
}

void hud_center_prompt(u8 row, u8 palette, const char *text)
{
    u8 len = 0;
    u8 col;
    const char *p = text;

    while (*p++)
        ++len;
    col = (u8)(16 - (len + 2) / 2);
    hud_panel(col, row, len);
    hud_text(col + 1, row + 1, palette, text);
    p = text;
    while (*p) {
        if (*p == '@')
            hud_tile(col + 1 + (u8)(p - text), row + 1,
                hud_entry(HUD_TILE_BUTTON_B, HUD_PAL_YELLOW));
        ++p;
    }
}

void hud_center_prompt_panel(u8 row, const char *text)
{
    u8 len;
    u8 col = hud_prompt_col(text, &len);

    hud_panel(col, row, len);
}

/* Half of the text (part 0, the first half; 1, the rest): a 28-character
 * line costs 816-tcc about 130 scanlines. */
void hud_center_prompt_half(u8 row, u8 palette, const char *text, u8 part)
{
    u8 len;
    u8 col = hud_prompt_col(text, &len);
    u8 from = part ? len >> 1 : 0;
    u8 to = part ? len : len >> 1;
    u16 index = (u16)(row + 1) * 32 + col + 1 + from;
    u8 c;

    for (; from < to; ++from) {
        c = (u8)text[from];
        if (c == '@')
            g_hud_map[index++] = hud_entry(HUD_TILE_BUTTON_B, HUD_PAL_YELLOW);
        else
            g_hud_map[index++] = hud_entry(c < 32 || c > 95 ? '?' : c,
                palette);
    }
    hud_mark(row + 1);
}

/* The upload, at most ASM_HUD_MAX_BANDS 256-byte bands per VBlank beside
 * the NMI's OAM DMA, is src/asm/hud_commit.asm (R18). */
u8 hud_commit_bit;

/* Forced-blank only: uploads every dirty band at once. */
void hud_commit_all(void)
{
    while (hud_dirty)
        hud_commit();
}
