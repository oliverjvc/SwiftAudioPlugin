#include "ParameterAtomics.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
_Static_assert(ATOMIC_INT_LOCK_FREE == 2, "Audio parameters require lock-free atomics");
struct ParameterAtomics { size_t reserved; _Atomic(uint32_t) values[]; };
ParameterAtomics *ParameterAtomicsCreate(size_t count) {
    ParameterAtomics *store = calloc(1, sizeof(*store) + count * sizeof(_Atomic(uint32_t)));
    if (store) for (size_t i = 0; i < count; ++i) atomic_init(&store->values[i], 0);
    return store;
}
void ParameterAtomicsDestroy(ParameterAtomics *store) { free(store); }
float ParameterAtomicsLoad(const ParameterAtomics *store, size_t index) {
    uint32_t bits = atomic_load_explicit(&store->values[index], memory_order_relaxed);
    float value; memcpy(&value, &bits, sizeof(value)); return value;
}
void ParameterAtomicsStore(ParameterAtomics *store, size_t index, float value) {
    uint32_t bits; memcpy(&bits, &value, sizeof(bits));
    atomic_store_explicit(&store->values[index], bits, memory_order_relaxed);
}
