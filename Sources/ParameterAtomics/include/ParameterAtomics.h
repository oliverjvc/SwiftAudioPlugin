#ifndef PARAMETER_ATOMICS_H
#define PARAMETER_ATOMICS_H
#include <stddef.h>
typedef struct ParameterAtomics ParameterAtomics;
ParameterAtomics *ParameterAtomicsCreate(size_t count);
void ParameterAtomicsDestroy(ParameterAtomics *store);
float ParameterAtomicsLoad(const ParameterAtomics *store, size_t index);
void ParameterAtomicsStore(ParameterAtomics *store, size_t index, float value);
#endif
