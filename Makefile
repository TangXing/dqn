# The makefile for caffe. Pretty hacky.
PROJECT := caffe

include Makefile.config

##############################################################################
# After this line, things should happen automatically.
##############################################################################

# The target static library and shared library name
NAME := lib$(PROJECT).so
STATIC_NAME := lib$(PROJECT).a

##############################
# Get all source files
##############################
# CXX_SRCS are the source files excluding the test ones.
CXX_SRCS := $(shell find src/$(PROJECT) ! -name "test_*.cpp" -name "*.cpp")
# HXX_SRCS are the header files
HXX_SRCS := $(shell find include/$(PROJECT) ! -name "*.hpp")
# CU_SRCS are the cuda source files
CU_SRCS := $(shell find src/$(PROJECT) -name "*.cu")
# TEST_SRCS are the test source files
TEST_MAIN_SRC := src/$(PROJECT)/test/test_caffe_main.cpp
TEST_SRCS := $(shell find src/$(PROJECT) -name "test_*.cpp")
TEST_SRCS := $(filter-out $(TEST_MAIN_SRC), $(TEST_SRCS))
GTEST_SRC := src/gtest/gtest-all.cpp
# TEST_HDRS are the test header files
TEST_HDRS := $(shell find src/$(PROJECT) -name "test_*.hpp")
# TOOL_SRCS are the source files for the tool binaries
TOOL_SRCS := $(shell find tools -name "*.cpp")
# EXAMPLE_SRCS are the source files for the example binaries
EXAMPLE_SRCS := $(shell find examples -name "*.cpp")
# BUILD_INCLUDE_DIR contains any generated header files we want to include.
BUILD_INCLUDE_DIR := $(BUILD_DIR)/include
# PROTO_SRCS are the protocol buffer defions
PROTO_SRC_DIR := src/$(PROJECT)/proto
PROTO_SRCS := $(wildcard $(PROTO_SRC_DIR)/*.proto)
# PROTO_BUILD_DIR will contain the .cc and obj files generated from
# PROTO_SRCS; PROTO_BUILD_INCLUDE_DIR will contain the .h header files
PROTO_BUILD_DIR := $(BUILD_DIR)/$(PROTO_SRC_DIR)
PROTO_BUILD_INCLUDE_DIR := $(BUILD_INCLUDE_DIR)/$(PROJECT)/proto
# NONGEN_CXX_SRCS includes all source/header files except those generated
# automatically (e.g., by proto).
NONGEN_CXX_SRCS := $(shell find \
	src/$(PROJECT) \
	include/$(PROJECT) \
	python/$(PROJECT) \
	matlab/$(PROJECT) \
	examples \
	tools \
	-name "*.cpp" -or -name "*.hpp" -or -name "*.cu" -or -name "*.cuh")
LINT_REPORT := $(BUILD_DIR)/cpp_lint.log
FAILED_LINT_REPORT := $(BUILD_DIR)/cpp_lint.error_log
# PY$(PROJECT)_SRC is the python wrapper for $(PROJECT)
PY$(PROJECT)_SRC := python/$(PROJECT)/_$(PROJECT).cpp
PY$(PROJECT)_SO := python/$(PROJECT)/_$(PROJECT).so
# MAT$(PROJECT)_SRC is the matlab wrapper for $(PROJECT)
MAT$(PROJECT)_SRC := matlab/$(PROJECT)/mat$(PROJECT).cpp
MAT$(PROJECT)_SO := matlab/$(PROJECT)/$(PROJECT)

##############################
# Derive generated files
##############################
# The generated files for protocol buffers
PROTO_GEN_HEADER_SRCS := $(addprefix $(PROTO_BUILD_DIR)/, \
	$(notdir ${PROTO_SRCS:.proto=.pb.h}))
PROTO_GEN_HEADER := $(addprefix $(PROTO_BUILD_INCLUDE_DIR)/, \
	$(notdir ${PROTO_SRCS:.proto=.pb.h}))
HXX_SRCS += $(PROTO_GEN_HEADER)
PROTO_GEN_CC := $(addprefix $(BUILD_DIR)/, ${PROTO_SRCS:.proto=.pb.cc})
PROTO_GEN_PY := $(foreach file,${PROTO_SRCS:.proto=_pb2.py},python/$(PROJECT)/proto/$(notdir $(file)))
# The objects corresponding to the source files
# These objects will be linked into the final shared library, so we
# exclude the tool, example, and test objects.
CXX_OBJS := $(addprefix $(BUILD_DIR)/, ${CXX_SRCS:.cpp=.o})
CU_OBJS := $(addprefix $(BUILD_DIR)/, ${CU_SRCS:.cu=.cuo})
PROTO_OBJS := ${PROTO_GEN_CC:.cc=.o}
OBJ_BUILD_DIR := $(BUILD_DIR)/src/$(PROJECT)
LAYER_BUILD_DIR := $(OBJ_BUILD_DIR)/layers
UTIL_BUILD_DIR := $(OBJ_BUILD_DIR)/util
OBJS := $(PROTO_OBJS) $(CXX_OBJS) $(CU_OBJS)
# tool, example, and test objects
TOOL_OBJS := $(addprefix $(BUILD_DIR)/, ${TOOL_SRCS:.cpp=.o})
TOOL_BUILD_DIR := $(BUILD_DIR)/tools
TOOL_BUILD_DIRS := $(sort $(foreach obj,$(TOOL_OBJS),$(dir $(obj))))
TEST_BUILD_DIR := $(BUILD_DIR)/src/$(PROJECT)/test
TEST_OBJS := $(addprefix $(BUILD_DIR)/, ${TEST_SRCS:.cpp=.o})
GTEST_OBJ := $(addprefix $(BUILD_DIR)/, ${GTEST_SRC:.cpp=.o})
GTEST_BUILD_DIR := $(dir $(GTEST_OBJ))
EXAMPLE_OBJS := $(addprefix $(BUILD_DIR)/, ${EXAMPLE_SRCS:.cpp=.o})
EXAMPLE_BUILD_DIR := $(BUILD_DIR)/examples
EXAMPLE_BUILD_DIRS := $(EXAMPLE_BUILD_DIR)
EXAMPLE_BUILD_DIRS += $(foreach obj,$(EXAMPLE_OBJS),$(dir $(obj)))
# tool, example, and test bins
TOOL_BINS := ${TOOL_OBJS:.o=.bin}
EXAMPLE_BINS := ${EXAMPLE_OBJS:.o=.bin}
TEST_BINS := ${TEST_OBJS:.o=.testbin}
TEST_ALL_BIN := $(TEST_BUILD_DIR)/test_all.testbin
TEST_ALL_BINS := $(TEST_ALL_BIN) $(TEST_BINS)
# A shortcut to the directory of test binaries for convenience.
TEST_LINK_DIR := $(BUILD_DIR)/test
TEST_ALL_BIN_LINKS := $(foreach \
		bin,$(TEST_ALL_BINS),$(TEST_LINK_DIR)/$(notdir $(bin)))

##############################
# Derive include and lib directories
##############################
CUDA_INCLUDE_DIR := $(CUDA_DIR)/include
CUDA_LIB_DIR := $(CUDA_DIR)/lib64 $(CUDA_DIR)/lib
MKL_INCLUDE_DIR := $(MKL_DIR)/include
MKL_LIB_DIR := $(MKL_DIR)/lib $(MKL_DIR)/lib/intel64

INCLUDE_DIRS += ./src ./include $(CUDA_INCLUDE_DIR)
INCLUDE_DIRS += $(BUILD_INCLUDE_DIR)
LIBRARY_DIRS += $(CUDA_LIB_DIR)
LIBRARIES := cudart cublas curand \
	pthread \
	glog protobuf leveldb snappy \
	boost_system \
	hdf5_hl hdf5 \
	opencv_core opencv_highgui opencv_imgproc
PYTHON_LIBRARIES := boost_python python2.7
WARNINGS := -Wall

##############################
# Set build directories
##############################

DISTRIBUTE_SUBDIRS := $(DISTRIBUTE_DIR)/bin $(DISTRIBUTE_DIR)/lib
DIST_ALIASES := dist
ifneq ($(strip $(DISTRIBUTE_DIR)),distribute)
		DIST_ALIASES += distribute
endif

ALL_BUILD_DIRS := $(BUILD_DIR) $(OBJ_BUILD_DIR) \
		$(LAYER_BUILD_DIR) $(UTIL_BUILD_DIR) $(TOOL_BUILD_DIRS) \
		$(TEST_BUILD_DIR) $(TEST_LINK_DIR) $(GTEST_BUILD_DIR) \
		$(EXAMPLE_BUILD_DIRS) \
		$(PROTO_BUILD_DIR) $(PROTO_BUILD_INCLUDE_DIR) \
		$(DISTRIBUTE_SUBDIRS)

ALL_BUILD_DIRS := $(sort $(ALL_BUILD_DIRS))

DEBUG ?= 0
ifeq ($(DEBUG), 1)
	COMMON_FLAGS := -DDEBUG -g -O0
else
	COMMON_FLAGS := -DNDEBUG -O2
endif

# MKL switch (default = non-MKL)
USE_MKL ?= 0
ifeq ($(USE_MKL), 1)
  LIBRARIES += mkl_rt
  COMMON_FLAGS += -DUSE_MKL
  INCLUDE_DIRS += $(MKL_INCLUDE_DIR)
  LIBRARY_DIRS += $(MKL_LIB_DIR)
else
  LIBRARIES += cblas atlas
endif

COMMON_FLAGS += $(foreach includedir,$(INCLUDE_DIRS),-I$(includedir))
CXXFLAGS += -pthread -fPIC $(COMMON_FLAGS)
NVCCFLAGS := -ccbin=$(CXX) -Xcompiler -fPIC $(COMMON_FLAGS)
LDFLAGS += $(foreach librarydir,$(LIBRARY_DIRS),-L$(librarydir)) \
		$(foreach library,$(LIBRARIES),-l$(library))
PYTHON_LDFLAGS := $(LDFLAGS) $(foreach library,$(PYTHON_LIBRARIES),-l$(library))

# 'superclean' target recursively* deletes all files ending with an extension
# suggesting that Caffe built them.  This may be useful if you've built older
# versions of Caffe that do not place all generated files in a location known
# to make clean.
#
# 'supercleanlist' will list the files to be deleted by make superclean.
#
# * Recursive with the exception that symbolic links are never followed, per the
# default behavior of 'find'.
SUPERCLEAN_EXTS := .so .a .o .bin .testbin .pb.cc .pb.h _pb2.py .cuo

##############################
# Define build targets
##############################
.PHONY: all test clean linecount lint tools examples dist \
	py mat py$(PROJECT) mat$(PROJECT) proto runtest \
	superclean supercleanlist supercleanfiles

.SECONDARY: $(PROTO_GEN_HEADER_SRCS) $(TEST_BINS)

all: $(NAME) $(STATIC_NAME) tools examples

linecount: clean
	cloc --read-lang-def=$(PROJECT).cloc src/$(PROJECT)/

lint: $(LINT_REPORT)

$(LINT_REPORT): $(NONGEN_CXX_SRCS) | $(BUILD_DIR)
	@ (python ./scripts/cpp_lint.py $(NONGEN_CXX_SRCS) > $(LINT_REPORT) 2>&1 \
		&& (rm -f $(FAILED_LINT_REPORT); echo "No lint errors!")) || ( \
			mv $(LINT_REPORT) $(FAILED_LINT_REPORT); \
			grep -v "^Done processing " $(FAILED_LINT_REPORT); \
			echo "Found 1 or more lint errors; see log at $(FAILED_LINT_REPORT)"; \
			exit 1)

test: $(TEST_ALL_BIN_LINKS)

tools: $(TOOL_BINS)

examples: $(EXAMPLE_BINS)

py$(PROJECT): py

py: $(PY$(PROJECT)_SO) $(PROTO_GEN_PY)

$(PY$(PROJECT)_SO): $(STATIC_NAME) $(PY$(PROJECT)_SRC)
	$(CXX) -shared -o $@ $(PY$(PROJECT)_SRC) \
		$(STATIC_NAME) $(CXXFLAGS) $(PYTHON_LDFLAGS)
	@ echo

mat$(PROJECT): mat

mat: $(STATIC_NAME) $(MAT$(PROJECT)_SRC)
	$(MATLAB_DIR)/bin/mex $(MAT$(PROJECT)_SRC) $(STATIC_NAME) \
		CXXFLAGS="\$$CXXFLAGS $(CXXFLAGS) $(WARNINGS)" \
		CXXLIBS="\$$CXXLIBS $(LDFLAGS)" \
		-o $(MAT$(PROJECT)_SO)
	@ echo

runtest: $(TEST_ALL_BIN)
	$(TEST_ALL_BIN) $(TEST_GPUID)

$(ALL_BUILD_DIRS):
	@ mkdir -p $@

$(NAME): $(PROTO_OBJS) $(OBJS)
	$(CXX) -shared -o $(NAME) $(OBJS) $(CXXFLAGS) $(LDFLAGS) $(WARNINGS)
	@ echo

$(STATIC_NAME): $(PROTO_OBJS) $(OBJS)
	ar rcs $(STATIC_NAME) $(PROTO_OBJS) $(OBJS)
	@ echo

$(TEST_BUILD_DIR)/%.testbin: $(TEST_BUILD_DIR)/%.o $(GTEST_OBJ) $(STATIC_NAME) \
		| $(TEST_BUILD_DIR)
	$(CXX) $(TEST_MAIN_SRC) $< $(GTEST_OBJ) $(STATIC_NAME) \
		-o $@ $(CXXFLAGS) $(LDFLAGS) $(WARNINGS)
	@ echo

$(TEST_ALL_BIN): $(TEST_MAIN_SRC) $(TEST_OBJS) $(GTEST_OBJ) $(STATIC_NAME)
	$(CXX) $(TEST_MAIN_SRC) $(TEST_OBJS) $(GTEST_OBJ) $(STATIC_NAME) \
		-o $(TEST_ALL_BIN) $(CXXFLAGS) $(LDFLAGS) $(WARNINGS)
	@ echo

$(TEST_LINK_DIR)/%.testbin: $(TEST_BUILD_DIR)/%.testbin | $(TEST_LINK_DIR)
	@ $(RM) $@
	@ ln -s ../../$(TEST_BUILD_DIR)/$(@F) $@

$(TOOL_BINS): %.bin : %.o $(STATIC_NAME)
	$(CXX) $< $(STATIC_NAME) -o $@ $(CXXFLAGS) $(LDFLAGS) $(WARNINGS)
	@ echo

$(EXAMPLE_BINS): %.bin : %.o $(STATIC_NAME)
	$(CXX) $< $(STATIC_NAME) -o $@ $(CXXFLAGS) $(LDFLAGS) $(WARNINGS)
	@ echo

$(LAYER_BUILD_DIR)/%.o: \
		src/$(PROJECT)/layers/%.cpp $(HXX_SRCS) | $(LAYER_BUILD_DIR)
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@ echo

$(PROTO_BUILD_DIR)/%.pb.o: $(PROTO_BUILD_DIR)/%.pb.cc \
		$(PROTO_GEN_HEADER) | $(PROTO_BUILD_DIR)
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@ echo

$(TEST_BUILD_DIR)/%.o: src/$(PROJECT)/test/%.cpp $(HXX_SRCS) | $(TEST_BUILD_DIR)
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@ echo

$(UTIL_BUILD_DIR)/%.o: src/$(PROJECT)/util/%.cpp $(HXX_SRCS) | $(UTIL_BUILD_DIR)
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@ echo

$(GTEST_OBJ): $(GTEST_SRC) | $(GTEST_BUILD_DIR)
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@ echo

$(LAYER_BUILD_DIR)/%.cuo: \
		src/$(PROJECT)/layers/%.cu $(HXX_SRCS) | $(LAYER_BUILD_DIR)
	$(CUDA_DIR)/bin/nvcc $(NVCCFLAGS) $(CUDA_ARCH) -c $< -o $@
	@ echo

$(UTIL_BUILD_DIR)/%.cuo: src/$(PROJECT)/util/%.cu | $(UTIL_BUILD_DIR)
	$(CUDA_DIR)/bin/nvcc $(NVCCFLAGS) $(CUDA_ARCH) -c $< -o $@
	@ echo

$(TOOL_BUILD_DIR)/%.o: tools/%.cpp $(PROTO_GEN_HEADER) | $(TOOL_BUILD_DIR)
	$(CXX) $< $(CXXFLAGS) -c -o $@ $(LDFLAGS)
	@ echo

$(EXAMPLE_BUILD_DIR)/%.o: examples/%.cpp $(PROTO_GEN_HEADER) \
		| $(EXAMPLE_BUILD_DIRS)
	$(CXX) $< $(CXXFLAGS) -c -o $@ $(LDFLAGS)
	@ echo

$(BUILD_DIR)/src/$(PROJECT)/%.o: src/$(PROJECT)/%.cpp $(HXX_SRCS)
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@ echo

$(PROTO_GEN_PY): $(PROTO_SRCS)
	protoc --proto_path=src --python_out=python $(PROTO_SRCS)
	@ echo

proto: $(PROTO_GEN_CC) $(PROTO_GEN_HEADER)

$(PROTO_BUILD_DIR)/%.pb.cc $(PROTO_BUILD_DIR)/%.pb.h : \
		$(PROTO_SRC_DIR)/%.proto | $(PROTO_BUILD_DIR)
	protoc --proto_path=src --cpp_out=build/src $<
	@ echo

$(PROTO_BUILD_INCLUDE_DIR)/%.pb.h: $(PROTO_BUILD_DIR)/%.pb.h \
		| $(PROTO_BUILD_INCLUDE_DIR)
	@ $(RM) $(PROTO_BUILD_INCLUDE_DIR)/$(*F).pb.h
	@ ln -s ../../../../$(PROTO_BUILD_DIR)/$(*F).pb.h \
			$(PROTO_BUILD_INCLUDE_DIR)/$(*F).pb.h

clean:
	@- $(RM) $(NAME) $(STATIC_NAME)
	@- $(RM) $(PROTO_GEN_HEADER) $(PROTO_GEN_CC) $(PROTO_GEN_PY)
	@- $(RM) include/$(PROJECT)/proto/$(PROJECT).pb.h
	@- $(RM) python/$(PROJECT)/proto/$(PROJECT)_pb2.py
	@- $(RM) python/$(PROJECT)/*.so
	@- $(RM) -rf $(BUILD_DIR)
	@- $(RM) -rf $(DISTRIBUTE_DIR)

supercleanfiles:
	$(eval SUPERCLEAN_FILES := $(strip \
			$(foreach ext,$(SUPERCLEAN_EXTS), $(shell find . -name '*$(ext)'))))

supercleanlist: supercleanfiles
	@ \
	if [ -z "$(SUPERCLEAN_FILES)" ]; then \
	  echo "No generated files found."; \
	else \
	  echo $(SUPERCLEAN_FILES) | tr ' ' '\n'; \
	fi

superclean: clean supercleanfiles
	@ \
	if [ -z "$(SUPERCLEAN_FILES)" ]; then \
	  echo "No generated files found."; \
	else \
	  echo "Deleting the following generated files:"; \
	  echo $(SUPERCLEAN_FILES) | tr ' ' '\n'; \
	  $(RM) $(SUPERCLEAN_FILES); \
	fi

$(DIST_ALIASES): $(DISTRIBUTE_DIR)

$(DISTRIBUTE_DIR): all py $(HXX_SRCS) | $(DISTRIBUTE_SUBDIRS)
	# add include
	cp -r include $(DISTRIBUTE_DIR)/
	# add tool and example binaries
	cp $(TOOL_BINS) $(DISTRIBUTE_DIR)/bin
	cp $(EXAMPLE_BINS) $(DISTRIBUTE_DIR)/bin
	# add libraries
	cp $(NAME) $(DISTRIBUTE_DIR)/lib
	cp $(STATIC_NAME) $(DISTRIBUTE_DIR)/lib
	# add python - it's not the standard way, indeed...
	cp -r python $(DISTRIBUTE_DIR)/python
