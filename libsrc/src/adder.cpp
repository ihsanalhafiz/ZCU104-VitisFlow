#include "hls_header.h"

extern "C" void adder(const int *a, const int *b, int *c, int size) {
#pragma HLS INTERFACE m_axi port=a offset=slave bundle=gmem
#pragma HLS INTERFACE m_axi port=b offset=slave bundle=gmem
#pragma HLS INTERFACE m_axi port=c offset=slave bundle=gmem
#pragma HLS INTERFACE s_axilite port=a bundle=control
#pragma HLS INTERFACE s_axilite port=b bundle=control
#pragma HLS INTERFACE s_axilite port=c bundle=control
#pragma HLS INTERFACE s_axilite port=size bundle=control
#pragma HLS INTERFACE s_axilite port=return bundle=control

    if (size <= 0) {
        return;
    }

    for (int index = 0; index < size; ++index) {
#pragma HLS PIPELINE II=1
        c[index] = a[index] + b[index];
    }
}


