// Minimal C runtime for freestanding Doomgeneric builds on ChiffonOS.

typedef unsigned char u8;
typedef unsigned int u32;
typedef unsigned long usize;

typedef struct {
    usize size;
} heap_hdr_t;

static u8 g_heap[8 * 1024 * 1024];
static usize g_heap_off = 0;

static inline usize align_up(usize v, usize a) {
    return (v + (a - 1)) & ~(a - 1);
}

void *memcpy(void *dst, const void *src, usize n) {
    u8 *d = (u8 *)dst;
    const u8 *s = (const u8 *)src;
    for (usize i = 0; i < n; i++) d[i] = s[i];
    return dst;
}

void *memset(void *dst, int c, usize n) {
    u8 *d = (u8 *)dst;
    for (usize i = 0; i < n; i++) d[i] = (u8)c;
    return dst;
}

void *memmove(void *dst, const void *src, usize n) {
    u8 *d = (u8 *)dst;
    const u8 *s = (const u8 *)src;
    if (d < s) {
        for (usize i = 0; i < n; i++) d[i] = s[i];
    } else if (d > s) {
        for (usize i = n; i > 0; i--) d[i - 1] = s[i - 1];
    }
    return dst;
}

int memcmp(const void *a, const void *b, usize n) {
    const u8 *p = (const u8 *)a;
    const u8 *q = (const u8 *)b;
    for (usize i = 0; i < n; i++) {
        if (p[i] != q[i]) return (int)p[i] - (int)q[i];
    }
    return 0;
}

usize strlen(const char *s) {
    usize n = 0;
    while (s[n] != 0) n++;
    return n;
}

int strcmp(const char *a, const char *b) {
    while (*a && (*a == *b)) { a++; b++; }
    return (int)(unsigned char)*a - (int)(unsigned char)*b;
}

int strncmp(const char *a, const char *b, usize n) {
    for (usize i = 0; i < n; i++) {
        unsigned char ca = (unsigned char)a[i];
        unsigned char cb = (unsigned char)b[i];
        if (ca != cb) return (int)ca - (int)cb;
        if (ca == 0) return 0;
    }
    return 0;
}

char *strcpy(char *dst, const char *src) {
    char *d = dst;
    while ((*d++ = *src++) != 0) {}
    return dst;
}

char *strncpy(char *dst, const char *src, usize n) {
    usize i = 0;
    for (; i < n && src[i] != 0; i++) dst[i] = src[i];
    for (; i < n; i++) dst[i] = 0;
    return dst;
}

int atoi(const char *s) {
    int sign = 1;
    int v = 0;
    while (*s == ' ' || *s == '\t' || *s == '\n') s++;
    if (*s == '-') { sign = -1; s++; }
    else if (*s == '+') { s++; }
    while (*s >= '0' && *s <= '9') {
        v = v * 10 + (*s - '0');
        s++;
    }
    return v * sign;
}

void *malloc(usize size) {
    if (size == 0) return (void *)0;
    usize off = align_up(g_heap_off, 8);
    usize need = sizeof(heap_hdr_t) + size;
    if (off + need > sizeof(g_heap)) return (void *)0;
    heap_hdr_t *hdr = (heap_hdr_t *)&g_heap[off];
    hdr->size = size;
    void *p = (void *)(hdr + 1);
    g_heap_off = off + need;
    return p;
}

void free(void *ptr) {
    (void)ptr; // bump allocator: no free
}

void *calloc(usize nmemb, usize size) {
    usize total = nmemb * size;
    void *p = malloc(total);
    if (p) memset(p, 0, total);
    return p;
}

void *realloc(void *ptr, usize size) {
    if (!ptr) return malloc(size);
    if (size == 0) return (void *)0;
    heap_hdr_t *hdr = ((heap_hdr_t *)ptr) - 1;
    usize old = hdr->size;
    void *p = malloc(size);
    if (p) {
        usize copy = old < size ? old : size;
        memcpy(p, ptr, copy);
    }
    return p;
}

// Very small stubs; replace with proper logging if needed.
int printf(const char *fmt, ...) { (void)fmt; return 0; }
int fprintf(void *stream, const char *fmt, ...) { (void)stream; (void)fmt; return 0; }
int puts(const char *s) { (void)s; return 0; }
int putchar(int c) { (void)c; return c; }

// Exit/abort hooks
static inline void syscall_exit(int code) {
    register usize a0 asm("a0") = (usize)code;
    register usize a7 asm("a7") = 1; // SYSCALL_EXIT
    asm volatile("ecall" : : "r"(a0), "r"(a7) : "memory");
    while (1) {}
}

void exit(int code) { syscall_exit(code); }
void _exit(int code) { syscall_exit(code); }
void abort(void) { syscall_exit(1); }
