// CPU host test for the HLS kernel: treat the kernel as a normal C function
#include <iostream>
#include <vector>
#include <random>
#include <string>
#include <iomanip>
#include <algorithm>
#include <cstdlib>
#include "hls_header.h"

int main(int argc, char **argv) {
    const int size = (argc >= 2) ? std::stoi(argv[1]) : 1024;
    if (size <= 0) {
        std::cerr << "Invalid size. Must be > 0\n";
        return EXIT_FAILURE;
    }

    std::vector<int> hostA(size), hostB(size), hostC(size, 0);

    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(-1000, 1000);
    for (int i = 0; i < size; ++i) {
        hostA[i] = dist(rng);
        hostB[i] = dist(rng);
    }

    // Call the HLS kernel as a plain C function
    adder(hostA.data(), hostB.data(), hostC.data(), size);

    // Verify results
    size_t errors = 0;
    for (int i = 0; i < size; ++i) {
        int expected = hostA[i] + hostB[i];
        if (hostC[i] != expected) {
            if (errors < 10) {
                std::cerr << "Mismatch at index " << i << ": got " << hostC[i]
                          << ", expected " << expected << "\n";
            }
            ++errors;
        }
    }

    if (errors == 0) {
        std::cout << "TEST PASSED (size=" << size << ")\n";
        // Print a small sample for visual confirmation
        int sample = std::min(size, 5);
        std::cout << "Sample results:";
        for (int i = 0; i < sample; ++i) {
            std::cout << " " << hostA[i] << "+" << hostB[i] << "=" << hostC[i];
        }
        std::cout << "\n";
        return EXIT_SUCCESS;
    } else {
        std::cout << "TEST FAILED with " << errors << " mismatches (size=" << size << ")\n";
        return EXIT_FAILURE;
    }
}


