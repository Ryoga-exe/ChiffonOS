// Temporary stub for doomgeneric. Replace this file with the real
// doomgeneric sources when ready.

typedef unsigned char u8;
typedef unsigned int u32;
typedef unsigned long usize;

typedef u32 pixel_t;

extern void DG_Init(void);
extern void DG_DrawFrame(void);
extern void DG_SleepMs(u32 ms);

pixel_t *DG_ScreenBuffer = (pixel_t *)0;
extern u32 dg_fb_width;
extern u32 dg_fb_height;
extern u32 dg_fb_stride;

static u32 frame = 0;

void doomgeneric_Create(int argc, char **argv) {
    (void)argc;
    (void)argv;
    DG_Init();
}

void doomgeneric_Tick(void) {
    if (!DG_ScreenBuffer) {
        DG_SleepMs(16);
        return;
    }

    u32 w = dg_fb_width ? dg_fb_width : 640;
    u32 h = dg_fb_height ? dg_fb_height : 480;
    u32 stride = dg_fb_stride ? dg_fb_stride : (w * 4);

    // Simple moving scanline to validate framebuffer output.
    u32 y = frame % h;
    for (u32 yy = 0; yy < h; yy++) {
        pixel_t *row = (pixel_t *)((u8 *)DG_ScreenBuffer + (usize)yy * stride);
        pixel_t color = (yy == y) ? 0x00FF0000u : 0x00000000u;
        for (u32 x = 0; x < w; x++) {
            row[x] = color;
        }
    }

    DG_DrawFrame();
    frame++;
    DG_SleepMs(16);
}
