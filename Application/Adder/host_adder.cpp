#define CL_HPP_MINIMUM_OPENCL_VERSION 120
#define CL_HPP_TARGET_OPENCL_VERSION 120
#include <CL/opencl.hpp>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

// Utility to read a whole binary file (xclbin)
static bool readBinaryFile(const std::string &filePath, std::vector<unsigned char> &outBuffer) {
    std::ifstream stream(filePath, std::ios::binary | std::ios::ate);
    if (!stream) {
        std::cerr << "Failed to open file: " << filePath << "\n";
        return false;
    }
    std::streamsize size = stream.tellg();
    if (size <= 0) {
        std::cerr << "File is empty: " << filePath << "\n";
        return false;
    }
    stream.seekg(0, std::ios::beg);
    outBuffer.resize(static_cast<size_t>(size));
    if (!stream.read(reinterpret_cast<char*>(outBuffer.data()), size)) {
        std::cerr << "Failed to read file: " << filePath << "\n";
        return false;
    }
    return true;
}

static bool getXilinxDevice(cl::Device &outDevice) {
    std::vector<cl::Platform> platforms;
    cl::Platform::get(&platforms);
    for (auto &platform : platforms) {
        std::string platformName = platform.getInfo<CL_PLATFORM_NAME>();
        if (platformName.find("Xilinx") != std::string::npos) {
            std::vector<cl::Device> devices;
            platform.getDevices(CL_DEVICE_TYPE_ACCELERATOR, &devices);
            if (!devices.empty()) {
                // Optionally filter for ZynqMP devices
                for (auto &dev : devices) {
                    std::string devName = dev.getInfo<CL_DEVICE_NAME>();
                    if (devName.find("Zynq") != std::string::npos || devName.find("xilinx") != std::string::npos) {
                        outDevice = dev;
                        return true;
                    }
                }
                outDevice = devices.front();
                return true;
            }
        }
    }
    std::cerr << "No Xilinx platform/device found." << "\n";
    return false;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <kernel.xclbin> [size]\n";
        return EXIT_FAILURE;
    }

    const std::string xclbinPath = argv[1];
    const int size = (argc >= 3) ? std::stoi(argv[2]) : 1024;
    if (size <= 0) {
        std::cerr << "Invalid size. Must be > 0\n";
        return EXIT_FAILURE;
    }

    // Select device and create context/queue
    cl::Device device;
    if (!getXilinxDevice(device)) {
        return EXIT_FAILURE;
    }

    cl_int err = CL_SUCCESS;
    cl::Context context(device, nullptr, nullptr, nullptr, &err);
    if (err != CL_SUCCESS) {
        std::cerr << "Failed to create context" << "\n";
        return EXIT_FAILURE;
    }

    cl::CommandQueue q(context, device, CL_QUEUE_PROFILING_ENABLE, &err);
    if (err != CL_SUCCESS) {
        std::cerr << "Failed to create command queue" << "\n";
        return EXIT_FAILURE;
    }

    // Load xclbin and create program
    std::vector<unsigned char> binary;
    if (!readBinaryFile(xclbinPath, binary)) {
        return EXIT_FAILURE;
    }
    cl::Program::Binaries bins;
    bins.push_back(binary);
    cl::Program program(context, {device}, bins, nullptr, &err);
    if (err != CL_SUCCESS) {
        std::cerr << "Failed to create program from binary" << "\n";
        return EXIT_FAILURE;
    }

    // Create kernel
    cl::Kernel kernel(program, "adder", &err);
    if (err != CL_SUCCESS) {
        std::cerr << "Failed to create kernel 'adder'" << "\n";
        return EXIT_FAILURE;
    }

    // Host buffers
    std::vector<int> hostA(size), hostB(size), hostC(size, 0);
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(-1000, 1000);
    for (int i = 0; i < size; ++i) {
        hostA[i] = dist(rng);
        hostB[i] = dist(rng);
    }

    // Device buffers
    cl::Buffer bufA(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR,
                    sizeof(int) * hostA.size(), hostA.data(), &err);
    if (err != CL_SUCCESS) {
        std::cerr << "Failed to allocate bufA" << "\n";
        return EXIT_FAILURE;
    }

    cl::Buffer bufB(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR,
                    sizeof(int) * hostB.size(), hostB.data(), &err);
    if (err != CL_SUCCESS) {
        std::cerr << "Failed to allocate bufB" << "\n";
        return EXIT_FAILURE;
    }

    cl::Buffer bufC(context, CL_MEM_WRITE_ONLY,
                    sizeof(int) * hostC.size(), nullptr, &err);
    if (err != CL_SUCCESS) {
        std::cerr << "Failed to allocate bufC" << "\n";
        return EXIT_FAILURE;
    }

    // Set kernel args
    int argIndex = 0;
    if (kernel.setArg(argIndex++, bufA) != CL_SUCCESS) {
        std::cerr << "setArg A failed" << "\n";
        return EXIT_FAILURE;
    }
    if (kernel.setArg(argIndex++, bufB) != CL_SUCCESS) {
        std::cerr << "setArg B failed" << "\n";
        return EXIT_FAILURE;
    }
    if (kernel.setArg(argIndex++, bufC) != CL_SUCCESS) {
        std::cerr << "setArg C failed" << "\n";
        return EXIT_FAILURE;
    }
    if (kernel.setArg(argIndex++, size) != CL_SUCCESS) {
        std::cerr << "setArg size failed" << "\n";
        return EXIT_FAILURE;
    }

    // Migrate input buffers
    std::vector<cl::Memory> toDevice{bufA, bufB};
    if (q.enqueueMigrateMemObjects(toDevice, 0) != CL_SUCCESS) {
        std::cerr << "enqueueMigrateMemObjects to device failed" << "\n";
        return EXIT_FAILURE;
    }

    // Launch kernel
    cl::Event event;
    if (q.enqueueTask(kernel, nullptr, &event) != CL_SUCCESS) {
        std::cerr << "enqueueTask failed" << "\n";
        return EXIT_FAILURE;
    }
    q.finish();

    // Read back results
    if (q.enqueueReadBuffer(
            bufC,
            CL_TRUE,
            0,
            sizeof(int) * hostC.size(),
            hostC.data()) != CL_SUCCESS) {
        std::cerr << "enqueueReadBuffer for bufC failed" << "\n";
        return EXIT_FAILURE;
    }

    // Verify
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
    } else {
        std::cout << "TEST FAILED with " << errors << " mismatches (size=" << size << ")\n";
        return EXIT_FAILURE;
    }

    // Optional: print kernel execution time
    if (event()) {
        cl_ulong start = event.getProfilingInfo<CL_PROFILING_COMMAND_START>();
        cl_ulong end   = event.getProfilingInfo<CL_PROFILING_COMMAND_END>();
        double ms = static_cast<double>(end - start) * 1e-6;
        std::cout << std::fixed << std::setprecision(3)
                  << "Kernel time: " << ms << " ms\n";
    }

    return EXIT_SUCCESS;
}


