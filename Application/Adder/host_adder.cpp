#include <CL/cl2.hpp>
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
static std::vector<unsigned char> readBinaryFile(const std::string &filePath) {
    std::ifstream stream(filePath, std::ios::binary | std::ios::ate);
    if (!stream) {
        throw std::runtime_error("Failed to open file: " + filePath);
    }
    std::streamsize size = stream.tellg();
    if (size <= 0) {
        throw std::runtime_error("File is empty: " + filePath);
    }
    stream.seekg(0, std::ios::beg);
    std::vector<unsigned char> buffer(static_cast<size_t>(size));
    if (!stream.read(reinterpret_cast<char*>(buffer.data()), size)) {
        throw std::runtime_error("Failed to read file: " + filePath);
    }
    return buffer;
}

static cl::Device getXilinxDevice() {
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
                        return dev;
                    }
                }
                return devices.front();
            }
        }
    }
    throw std::runtime_error("No Xilinx platform/device found.");
}

int main(int argc, char **argv) {
    try {
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
        cl::Device device = getXilinxDevice();
        cl_int err = CL_SUCCESS;
        cl::Context context(device, nullptr, nullptr, nullptr, &err);
        if (err != CL_SUCCESS) throw std::runtime_error("Failed to create context");

        cl::CommandQueue q(context, device, CL_QUEUE_PROFILING_ENABLE, &err);
        if (err != CL_SUCCESS) throw std::runtime_error("Failed to create command queue");

        // Load xclbin and create program
        auto binary = readBinaryFile(xclbinPath);
        cl::Program::Binaries bins{{binary.data(), binary.size()}};
        cl::Program program(context, {device}, bins, nullptr, &err);
        if (err != CL_SUCCESS) throw std::runtime_error("Failed to create program from binary");

        // Create kernel
        cl::Kernel kernel(program, "adder", &err);
        if (err != CL_SUCCESS) throw std::runtime_error("Failed to create kernel 'adder'");

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
        if (err != CL_SUCCESS) throw std::runtime_error("Failed to allocate bufA");

        cl::Buffer bufB(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR,
                        sizeof(int) * hostB.size(), hostB.data(), &err);
        if (err != CL_SUCCESS) throw std::runtime_error("Failed to allocate bufB");

        cl::Buffer bufC(context, CL_MEM_WRITE_ONLY,
                        sizeof(int) * hostC.size(), nullptr, &err);
        if (err != CL_SUCCESS) throw std::runtime_error("Failed to allocate bufC");

        // Set kernel args
        int argIndex = 0;
        if (kernel.setArg(argIndex++, bufA) != CL_SUCCESS) throw std::runtime_error("setArg A failed");
        if (kernel.setArg(argIndex++, bufB) != CL_SUCCESS) throw std::runtime_error("setArg B failed");
        if (kernel.setArg(argIndex++, bufC) != CL_SUCCESS) throw std::runtime_error("setArg C failed");
        if (kernel.setArg(argIndex++, size) != CL_SUCCESS) throw std::runtime_error("setArg size failed");

        // Migrate input buffers
        std::vector<cl::Memory> toDevice{bufA, bufB};
        if (q.enqueueMigrateMemObjects(toDevice, 0) != CL_SUCCESS) throw std::runtime_error("enqueueMigrateMemObjects to device failed");

        // Launch kernel
        cl::Event event; 
        if (q.enqueueTask(kernel, nullptr, &event) != CL_SUCCESS) throw std::runtime_error("enqueueTask failed");
        q.finish();

        // Read back
        std::vector<cl::Memory> fromDevice{bufC};
        if (q.enqueueMigrateMemObjects(fromDevice, CL_MIGRATE_MEM_OBJECT_HOST) != CL_SUCCESS) throw std::runtime_error("enqueueMigrateMemObjects to host failed");
        q.finish();

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
    } catch (const cl::Error &e) {
        std::cerr << "OpenCL Error: " << e.what() << ": " << e.err() << "\n";
        return EXIT_FAILURE;
    } catch (const std::exception &e) {
        std::cerr << "Error: " << e.what() << "\n";
        return EXIT_FAILURE;
    }
}


