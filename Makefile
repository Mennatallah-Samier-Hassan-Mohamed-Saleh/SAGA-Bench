# Compiler and flags
CXX = g++
CXXFLAGS = -O2 -Wall -Wextra -pedantic -std=c++17 -fopenmp

# Directories
ABSEIL_DIR := external/abseil-cpp
DYN_PREFIX := d_
DYN_DIR := src/dynamic
UTL_DIR := src/common
OBJ_DIR := obj
BIN_DIR := bin
PIGO_DIR := include

# Includes
INCLUDES = -I$(ABSEIL_DIR) -I$(DYN_DIR) -I$(UTL_DIR) -I$(PIGO_DIR)
CXXFLAGS += $(INCLUDES)

# Source files
#DYN_SRC_CC := $(wildcard $(DYN_DIR)/*.cc)
#exclude builder.cc since dequeAndInsertEdge is no longer used
DYN_SRC_CC := $(filter-out $(DYN_DIR)/builder.cc, $(wildcard $(DYN_DIR)/*.cc))
DYN_SRC_C := $(wildcard $(DYN_DIR)/*.c)
UTL_SRC_CC := $(wildcard $(UTL_DIR)/*.cc)
DYN_HDR := $(wildcard $(DYN_DIR)/*.h) $(wildcard $(UTL_DIR)/*.h)

# Object files
DYN_OBJ := $(addprefix $(OBJ_DIR)/$(DYN_PREFIX),$(notdir $(patsubst %.c,%.o,$(DYN_SRC_C))))
DYN_OBJ += $(addprefix $(OBJ_DIR)/$(DYN_PREFIX),$(notdir $(patsubst %.cc,%.o,$(DYN_SRC_CC))))
UTL_OBJ := $(addprefix $(OBJ_DIR)/$(DYN_PREFIX),$(notdir $(patsubst %.cc,%.o,$(UTL_SRC_CC))))

# Combine all objects
ALL_OBJ := $(DYN_OBJ) $(UTL_OBJ)

.PHONY: all clean

all: $(BIN_DIR)/errorExtractor frontEnd

# Compile dynamic .cc files
$(OBJ_DIR)/$(DYN_PREFIX)%.o : $(DYN_DIR)/%.cc $(DYN_HDR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile dynamic .c files
$(OBJ_DIR)/$(DYN_PREFIX)%.o : $(DYN_DIR)/%.c $(DYN_HDR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile common .cc files
$(OBJ_DIR)/$(DYN_PREFIX)%.o : $(UTL_DIR)/%.cc $(DYN_HDR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# errorExtractor target (single file)
$(BIN_DIR)/errorExtractor : errorExtractor.cc
	$(CXX) $(CXXFLAGS) $< -o $@

# frontEnd target links all objects (Abseil used as header-only)
frontEnd : $(ALL_OBJ)
	$(CXX) $(CXXFLAGS) $^ -o $@

clean:
	rm -f $(BIN_DIR)/*
	rm -f $(OBJ_DIR)/*.o
	rm -f frontEnd 