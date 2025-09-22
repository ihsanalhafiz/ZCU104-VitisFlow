# Compiler
GPP = g++

# Paths
INC_DIR = ../../../libsrc/include
SRCDIR = ../../../libsrc/src

# Compilation flags (CPU-only)
CFLAGS = -std=c++17 -O3 -g -I $(INC_DIR)

# Sources
HOST_SRC = hlshost_adder.cpp
KERNEL_SRC = $(SRCDIR)/adder.cpp

# Object files
OBJDIR = ./bin
OBJS = $(OBJDIR)/hlshost_adder.o \
       $(OBJDIR)/adder.o

# Executable
EXEC = ./hlshost_adder

# Default target
all: clean $(EXEC)

# Linking
$(EXEC): $(OBJS)
	$(GPP) $(OBJS) -o $@

# Compilation
$(OBJDIR)/hlshost_adder.o: $(HOST_SRC) | $(OBJDIR)
	$(GPP) $(CFLAGS) -c $< -o $@

$(OBJDIR)/adder.o: $(KERNEL_SRC) | $(OBJDIR)
	$(GPP) $(CFLAGS) -c $< -o $@

$(OBJDIR):
	mkdir -p $(OBJDIR)

# Clean
clean:
	rm -f $(OBJS) $(EXEC) *.log *~
