.PHONY : all validate clean build run

# variables
type:=debug

# constants
override bin_name:=niagara
override cmake_build_type_release:=Release
override cmake_build_type_debug:=Debug
override cmake_build_type_minsizerel:=MinSizeRel
override cmake_build_type_relwithdebinfo:=RelWithDebInfo
override cmake_build_type:=$(cmake_build_type_$(type))
override build_path:=cmake-build-$(type)
override os:=$(shell uname)
override valid_types:=release debug relwithdebinfo minsizerel

# number of cores
ifeq ($(os),Darwin)
override cores:=$(shell sysctl -n hw.ncpu)
else ifeq ($(os),Linux)
override cores:=$(shell nproc --all)
else
override cores:=1
endif

all: | build

validate:
ifneq ($(type),$(filter $(type),$(valid_types)))
	@echo "Invalid release type: $(type). Valid types are: $(valid_types)" >&2
	@exit 1
else ifeq ($(strip $(type)),)
	@echo "Empty release type. Valid types are: $(valid_types)" >&2
	@exit 1
else
	@:
endif

clean: validate
	@rm -rf $(build_path)

prepare: validate
	@cmake -S . -B $(build_path) -DCMAKE_BUILD_TYPE=$(cmake_build_type) -G 'Unix Makefiles';

build: prepare
	@cmake --build $(build_path) -- -j$(cores);

run: build
	@cd $(build_path) && ./$(bin_name) data/kitten.obj
	@echo "\nProcessed finished with exit code $$?"

buildtests: prepare
	@cmake --build $(build_path) --target $(bin_name)_tests -- -j$(cores);

test: buildtests
	@cd $(build_path) && ctest
