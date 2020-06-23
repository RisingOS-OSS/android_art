#
# Copyright (C) 2011 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

LOCAL_PATH := $(call my-dir)

art_path := $(LOCAL_PATH)

########################################################################
# clean-oat rules
#

include $(art_path)/build/Android.common_path.mk

.PHONY: clean-oat
clean-oat: clean-oat-host clean-oat-target

.PHONY: clean-oat-host
clean-oat-host:
	find $(OUT_DIR) '(' -name '*.oat' -o -name '*.odex' -o -name '*.art' -o -name '*.vdex' ')' -a -type f | xargs rm -f
	rm -rf $(TMPDIR)/*/test-*/dalvik-cache/*
	rm -rf $(TMPDIR)/android-data/dalvik-cache/*

.PHONY: clean-oat-target
clean-oat-target:
	$(ADB) root
	$(ADB) wait-for-device remount
	$(ADB) shell rm -rf $(ART_TARGET_NATIVETEST_DIR)
	$(ADB) shell rm -rf $(ART_TARGET_TEST_DIR)
	$(ADB) shell rm -rf $(ART_TARGET_DALVIK_CACHE_DIR)/*/*
	$(ADB) shell rm -rf $(ART_DEXPREOPT_BOOT_JAR_DIR)/$(DEX2OAT_TARGET_ARCH)
	$(ADB) shell rm -rf system/app/$(DEX2OAT_TARGET_ARCH)
ifdef TARGET_2ND_ARCH
	$(ADB) shell rm -rf $(ART_DEXPREOPT_BOOT_JAR_DIR)/$($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_ARCH)
	$(ADB) shell rm -rf system/app/$($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_ARCH)
endif
	$(ADB) shell rm -rf data/run-test/test-*/dalvik-cache/*

########################################################################
# cpplint rules to style check art source files

include $(art_path)/build/Android.cpplint.mk

########################################################################
# product rules

include $(art_path)/oatdump/Android.mk
include $(art_path)/tools/ahat/Android.mk
include $(art_path)/tools/dexfuzz/Android.mk
include $(art_path)/tools/veridex/Android.mk

ART_HOST_DEPENDENCIES := \
  $(ART_HOST_EXECUTABLES) \
  $(ART_HOST_DEX_DEPENDENCIES) \
  $(ART_HOST_SHARED_LIBRARY_DEPENDENCIES)

ifeq ($(ART_BUILD_HOST_DEBUG),true)
ART_HOST_DEPENDENCIES += $(ART_HOST_SHARED_LIBRARY_DEBUG_DEPENDENCIES)
endif

ART_TARGET_DEPENDENCIES := \
  $(ART_TARGET_DEX_DEPENDENCIES)

########################################################################
# test rules

# All the dependencies that must be built ahead of sync-ing them onto the target device.
TEST_ART_TARGET_SYNC_DEPS := $(ADB_EXECUTABLE)

include $(art_path)/build/Android.common_test.mk
include $(art_path)/build/Android.gtest.mk
include $(art_path)/test/Android.run-test.mk

TEST_ART_TARGET_SYNC_DEPS += $(ART_TEST_TARGET_GTEST_DEPENDENCIES) $(ART_TEST_TARGET_RUN_TEST_DEPENDENCIES)

# Make sure /system is writable on the device.
TEST_ART_ADB_ROOT_AND_REMOUNT := \
    ($(ADB) root && \
     $(ADB) wait-for-device remount && \
     (($(ADB) shell touch /system/testfile && \
       ($(ADB) shell rm /system/testfile || true)) || \
      ($(ADB) disable-verity && \
       $(ADB) reboot && \
       $(ADB) wait-for-device root && \
       $(ADB) wait-for-device remount)))

# "mm test-art" to build and run all tests on host and device
.PHONY: test-art
test-art: test-art-host test-art-target
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-gtest
test-art-gtest: test-art-host-gtest test-art-target-gtest
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-run-test
test-art-run-test: test-art-host-run-test test-art-target-run-test
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

########################################################################
# host test rules

VIXL_TEST_DEPENDENCY :=
# We can only run the vixl tests on 64-bit hosts (vixl testing issue) when its a
# top-level build (to declare the vixl test rule).
ifneq ($(HOST_PREFER_32_BIT),true)
ifeq ($(ONE_SHOT_MAKEFILE),)
VIXL_TEST_DEPENDENCY := run-vixl-tests
endif
endif

.PHONY: test-art-host-vixl
test-art-host-vixl: $(VIXL_TEST_DEPENDENCY)

# "mm test-art-host" to build and run all host tests.
.PHONY: test-art-host
test-art-host: test-art-host-gtest test-art-host-run-test \
               test-art-host-vixl test-art-host-dexdump
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# All host tests that run solely with the default compiler.
.PHONY: test-art-host-default
test-art-host-default: test-art-host-run-test-default
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# All host tests that run solely with the optimizing compiler.
.PHONY: test-art-host-optimizing
test-art-host-optimizing: test-art-host-run-test-optimizing
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# All host tests that run solely on the interpreter.
.PHONY: test-art-host-interpreter
test-art-host-interpreter: test-art-host-run-test-interpreter
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# All host tests that run solely on the jit.
.PHONY: test-art-host-jit
test-art-host-jit: test-art-host-run-test-jit
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# Primary host architecture variants:
.PHONY: test-art-host$(ART_PHONY_TEST_HOST_SUFFIX)
test-art-host$(ART_PHONY_TEST_HOST_SUFFIX): test-art-host-gtest$(ART_PHONY_TEST_HOST_SUFFIX) \
    test-art-host-run-test$(ART_PHONY_TEST_HOST_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-host-default$(ART_PHONY_TEST_HOST_SUFFIX)
test-art-host-default$(ART_PHONY_TEST_HOST_SUFFIX): test-art-host-run-test-default$(ART_PHONY_TEST_HOST_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-host-optimizing$(ART_PHONY_TEST_HOST_SUFFIX)
test-art-host-optimizing$(ART_PHONY_TEST_HOST_SUFFIX): test-art-host-run-test-optimizing$(ART_PHONY_TEST_HOST_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-host-interpreter$(ART_PHONY_TEST_HOST_SUFFIX)
test-art-host-interpreter$(ART_PHONY_TEST_HOST_SUFFIX): test-art-host-run-test-interpreter$(ART_PHONY_TEST_HOST_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-host-jit$(ART_PHONY_TEST_HOST_SUFFIX)
test-art-host-jit$(ART_PHONY_TEST_HOST_SUFFIX): test-art-host-run-test-jit$(ART_PHONY_TEST_HOST_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# Secondary host architecture variants:
ifneq ($(HOST_PREFER_32_BIT),true)
.PHONY: test-art-host$(2ND_ART_PHONY_TEST_HOST_SUFFIX)
test-art-host$(2ND_ART_PHONY_TEST_HOST_SUFFIX): test-art-host-gtest$(2ND_ART_PHONY_TEST_HOST_SUFFIX) \
    test-art-host-run-test$(2ND_ART_PHONY_TEST_HOST_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-host-default$(2ND_ART_PHONY_TEST_HOST_SUFFIX)
test-art-host-default$(2ND_ART_PHONY_TEST_HOST_SUFFIX): test-art-host-run-test-default$(2ND_ART_PHONY_TEST_HOST_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-host-optimizing$(2ND_ART_PHONY_TEST_HOST_SUFFIX)
test-art-host-optimizing$(2ND_ART_PHONY_TEST_HOST_SUFFIX): test-art-host-run-test-optimizing$(2ND_ART_PHONY_TEST_HOST_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-host-interpreter$(2ND_ART_PHONY_TEST_HOST_SUFFIX)
test-art-host-interpreter$(2ND_ART_PHONY_TEST_HOST_SUFFIX): test-art-host-run-test-interpreter$(2ND_ART_PHONY_TEST_HOST_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-host-jit$(2ND_ART_PHONY_TEST_HOST_SUFFIX)
test-art-host-jit$(2ND_ART_PHONY_TEST_HOST_SUFFIX): test-art-host-run-test-jit$(2ND_ART_PHONY_TEST_HOST_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)
endif

# Dexdump/list regression test.
.PHONY: test-art-host-dexdump
test-art-host-dexdump: $(addprefix $(HOST_OUT_EXECUTABLES)/, dexdump dexlist)
	ANDROID_HOST_OUT=$(realpath $(HOST_OUT)) art/test/dexdump/run-all-tests

########################################################################
# target test rules

# "mm test-art-target" to build and run all target tests.
.PHONY: test-art-target
test-art-target: test-art-target-gtest test-art-target-run-test
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# All target tests that run solely with the default compiler.
.PHONY: test-art-target-default
test-art-target-default: test-art-target-run-test-default
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# All target tests that run solely with the optimizing compiler.
.PHONY: test-art-target-optimizing
test-art-target-optimizing: test-art-target-run-test-optimizing
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# All target tests that run solely on the interpreter.
.PHONY: test-art-target-interpreter
test-art-target-interpreter: test-art-target-run-test-interpreter
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# All target tests that run solely on the jit.
.PHONY: test-art-target-jit
test-art-target-jit: test-art-target-run-test-jit
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# Primary target architecture variants:
.PHONY: test-art-target$(ART_PHONY_TEST_TARGET_SUFFIX)
test-art-target$(ART_PHONY_TEST_TARGET_SUFFIX): test-art-target-gtest$(ART_PHONY_TEST_TARGET_SUFFIX) \
    test-art-target-run-test$(ART_PHONY_TEST_TARGET_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-target-default$(ART_PHONY_TEST_TARGET_SUFFIX)
test-art-target-default$(ART_PHONY_TEST_TARGET_SUFFIX): test-art-target-run-test-default$(ART_PHONY_TEST_TARGET_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-target-optimizing$(ART_PHONY_TEST_TARGET_SUFFIX)
test-art-target-optimizing$(ART_PHONY_TEST_TARGET_SUFFIX): test-art-target-run-test-optimizing$(ART_PHONY_TEST_TARGET_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-target-interpreter$(ART_PHONY_TEST_TARGET_SUFFIX)
test-art-target-interpreter$(ART_PHONY_TEST_TARGET_SUFFIX): test-art-target-run-test-interpreter$(ART_PHONY_TEST_TARGET_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-target-jit$(ART_PHONY_TEST_TARGET_SUFFIX)
test-art-target-jit$(ART_PHONY_TEST_TARGET_SUFFIX): test-art-target-run-test-jit$(ART_PHONY_TEST_TARGET_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

# Secondary target architecture variants:
ifdef 2ND_ART_PHONY_TEST_TARGET_SUFFIX
.PHONY: test-art-target$(2ND_ART_PHONY_TEST_TARGET_SUFFIX)
test-art-target$(2ND_ART_PHONY_TEST_TARGET_SUFFIX): test-art-target-gtest$(2ND_ART_PHONY_TEST_TARGET_SUFFIX) \
    test-art-target-run-test$(2ND_ART_PHONY_TEST_TARGET_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-target-default$(2ND_ART_PHONY_TEST_TARGET_SUFFIX)
test-art-target-default$(2ND_ART_PHONY_TEST_TARGET_SUFFIX): test-art-target-run-test-default$(2ND_ART_PHONY_TEST_TARGET_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-target-optimizing$(2ND_ART_PHONY_TEST_TARGET_SUFFIX)
test-art-target-optimizing$(2ND_ART_PHONY_TEST_TARGET_SUFFIX): test-art-target-run-test-optimizing$(2ND_ART_PHONY_TEST_TARGET_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-target-interpreter$(2ND_ART_PHONY_TEST_TARGET_SUFFIX)
test-art-target-interpreter$(2ND_ART_PHONY_TEST_TARGET_SUFFIX): test-art-target-run-test-interpreter$(2ND_ART_PHONY_TEST_TARGET_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)

.PHONY: test-art-target-jit$(2ND_ART_PHONY_TEST_TARGET_SUFFIX)
test-art-target-jit$(2ND_ART_PHONY_TEST_TARGET_SUFFIX): test-art-target-run-test-jit$(2ND_ART_PHONY_TEST_TARGET_SUFFIX)
	$(hide) $(call ART_TEST_PREREQ_FINISHED,$@)
endif


#######################
# ART APEX.

include $(CLEAR_VARS)

# The ART APEX comes in three flavors:
# - the release module (`com.android.art.release`), containing
#   only "release" artifacts;
# - the debug module (`com.android.art.debug`), containing both
#   "release" and "debug" artifacts, as well as additional tools;
# - the testing module (`com.android.art.testing`), containing
#   both "release" and "debug" artifacts, as well as additional tools
#   and ART gtests).
#
# The ART APEX module (`com.android.art`) is an "alias" for either the
# release or the debug module. By default, "user" build variants contain
# the release module, while "userdebug" and "eng" build variants contain
# the debug module. However, if `PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD`
# is defined, it overrides the previous logic:
# - if `PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD` is set to `false`, the
#   build will include the release module (whatever the build
#   variant);
# - if `PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD` is set to `true`, the
#   build will include the debug module (whatever the build variant).

art_target_include_debug_build := $(PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD)
ifneq (false,$(art_target_include_debug_build))
  ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
    art_target_include_debug_build := true
  endif
endif
ifeq (true,$(art_target_include_debug_build))
  # Module with both release and debug variants, as well as
  # additional tools.
  TARGET_ART_APEX := $(DEBUG_ART_APEX)
  APEX_TEST_MODULE := art-check-debug-apex-gen-fakebin
else
  # Release module (without debug variants nor tools).
  TARGET_ART_APEX := $(RELEASE_ART_APEX)
  APEX_TEST_MODULE := art-check-release-apex-gen-fakebin
endif

LOCAL_MODULE := com.android.art
LOCAL_REQUIRED_MODULES := $(TARGET_ART_APEX)

# Clear locally used variable.
art_target_include_debug_build :=

include $(BUILD_PHONY_PACKAGE)

include $(CLEAR_VARS)
LOCAL_MODULE := com.android.art
LOCAL_IS_HOST_MODULE := true
ifneq ($(HOST_OS),darwin)
  LOCAL_REQUIRED_MODULES += $(APEX_TEST_MODULE)
endif
include $(BUILD_PHONY_PACKAGE)

# Create canonical name -> file name symlink in the symbol directory
# The symbol files for the debug or release variant are installed to
# $(TARGET_OUT_UNSTRIPPED)/$(TARGET_ART_APEX) directory. However,
# since they are available via /apex/com.android.art at runtime
# regardless of which variant is installed, create a symlink so that
# $(TARGET_OUT_UNSTRIPPED)/apex/com.android.art is linked to
# $(TARGET_OUT_UNSTRIPPED)/apex/$(TARGET_ART_APEX).
# Note that installation of the symlink is triggered by the apex_manifest.pb
# file which is the file that is guaranteed to be created regardless of the
# value of TARGET_FLATTEN_APEX.
ifeq ($(TARGET_FLATTEN_APEX),true)
art_apex_manifest_file := $(PRODUCT_OUT)/system/apex/$(TARGET_ART_APEX)/apex_manifest.pb
else
art_apex_manifest_file := $(PRODUCT_OUT)/apex/$(TARGET_ART_APEX)/apex_manifest.pb
endif

art_apex_symlink_timestamp := $(call intermediates-dir-for,FAKE,com.android.art)/symlink.timestamp
$(art_apex_manifest_file): $(art_apex_symlink_timestamp)
$(art_apex_manifest_file): PRIVATE_LINK_NAME := $(TARGET_OUT_UNSTRIPPED)/apex/com.android.art
$(art_apex_symlink_timestamp):
	$(hide) mkdir -p $(dir $(PRIVATE_LINK_NAME))
	$(hide) ln -sf $(TARGET_ART_APEX) $(PRIVATE_LINK_NAME)
	$(hide) touch $@

art_apex_manifest_file :=

#######################
# Fake packages for ART

# The art-runtime package depends on the core ART libraries and binaries. It exists so we can
# manipulate the set of things shipped, e.g., add debug versions and so on.

include $(CLEAR_VARS)
LOCAL_MODULE := art-runtime

# Base requirements.
LOCAL_REQUIRED_MODULES := \
    dalvikvm.com.android.art.release \
    dex2oat.com.android.art.release \
    dexoptanalyzer.com.android.art.release \
    libart.com.android.art.release \
    libart-compiler.com.android.art.release \
    libopenjdkjvm.com.android.art.release \
    libopenjdkjvmti.com.android.art.release \
    profman.com.android.art.release \
    libadbconnection.com.android.art.release \
    libperfetto_hprof.com.android.art.release \

# Potentially add in debug variants:
#
# * We will never add them if PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD = false.
# * We will always add them if PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD = true.
# * Otherwise, we will add them by default to userdebug and eng builds.
art_target_include_debug_build := $(PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD)
ifneq (false,$(art_target_include_debug_build))
ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
  art_target_include_debug_build := true
endif
ifeq (true,$(art_target_include_debug_build))
LOCAL_REQUIRED_MODULES += \
    dex2oatd.com.android.art.debug \
    dexoptanalyzerd.com.android.art.debug \
    libartd.com.android.art.debug \
    libartd-compiler.com.android.art.debug \
    libopenjdkd.com.android.art.debug \
    libopenjdkjvmd.com.android.art.debug \
    libopenjdkjvmtid.com.android.art.debug \
    profmand.com.android.art.debug \
    libadbconnectiond.com.android.art.debug \
    libperfetto_hprofd.com.android.art.debug \

endif
endif

include $(BUILD_PHONY_PACKAGE)

# The art-tools package depends on helpers and tools that are useful for developers. Similar
# dependencies exist for the APEX builds for these tools (see build/apex/Android.bp).

include $(CLEAR_VARS)
LOCAL_MODULE := art-tools
LOCAL_IS_HOST_MODULE := true
LOCAL_REQUIRED_MODULES := \
    ahat \
    dexdump \
    hprof-conv \

# A subset of the tools are disabled when HOST_PREFER_32_BIT is defined as make reports that
# they are not supported on host (b/129323791). This is likely due to art_apex disabling host
# APEX builds when HOST_PREFER_32_BIT is set (b/120617876).
ifneq ($(HOST_PREFER_32_BIT),true)
LOCAL_REQUIRED_MODULES += \
    dexdiag \
    dexlist \
    oatdump \

endif

include $(BUILD_PHONY_PACKAGE)

####################################################################################################
# Fake packages to ensure generation of libopenjdkd when one builds with mm/mmm/mmma.
#
# The library is required for starting a runtime in debug mode, but libartd does not depend on it
# (dependency cycle otherwise).
#
# Note: * As the package is phony to create a dependency the package name is irrelevant.
#       * We make MULTILIB explicit to "both," just to state here that we want both libraries on
#         64-bit systems, even if it is the default.

# ART on the host.
ifeq ($(ART_BUILD_HOST_DEBUG),true)
include $(CLEAR_VARS)
LOCAL_MODULE := art-libartd-libopenjdkd-host-dependency
LOCAL_MULTILIB := both
LOCAL_REQUIRED_MODULES := libopenjdkd
LOCAL_IS_HOST_MODULE := true
include $(BUILD_PHONY_PACKAGE)
endif

# ART on the target.
ifeq ($(ART_BUILD_TARGET_DEBUG),true)
include $(CLEAR_VARS)
LOCAL_MODULE := art-libartd-libopenjdkd-target-dependency
LOCAL_MULTILIB := both
LOCAL_REQUIRED_MODULES := libopenjdkd
include $(BUILD_PHONY_PACKAGE)
endif

########################################################################
# "m build-art" for quick minimal build
.PHONY: build-art
build-art: build-art-host build-art-target

.PHONY: build-art-host
build-art-host:   $(HOST_OUT_EXECUTABLES)/art $(ART_HOST_DEPENDENCIES) $(HOST_CORE_IMG_OUTS)

.PHONY: build-art-target
build-art-target: $(TARGET_OUT_EXECUTABLES)/art $(ART_TARGET_DEPENDENCIES) $(TARGET_CORE_IMG_OUTS)

PRIVATE_ART_APEX_DEPENDENCY_FILES := \
  bin/dalvikvm32 \
  bin/dalvikvm64 \
  bin/dalvikvm \
  bin/dex2oat32 \
  bin/dex2oat64 \
  bin/dexdump \

PRIVATE_ART_APEX_DEPENDENCY_LIBS := \
  lib/libadbconnection.so \
  lib/libandroidio.so \
  lib/libartbase.so \
  lib/libart-compiler.so \
  lib/libart-dexlayout.so \
  lib/libart-disassembler.so \
  lib/libartpalette.so \
  lib/libart.so \
  lib/libdexfile_external.so \
  lib/libdexfile.so \
  lib/libdt_fd_forward.so \
  lib/libdt_socket.so \
  lib/libexpat.so \
  lib/libjavacore.so \
  lib/libjdwp.so \
  lib/libmeminfo.so \
  lib/libnativebridge.so \
  lib/libnativehelper.so \
  lib/libnativeloader.so \
  lib/libnpt.so \
  lib/libopenjdkjvm.so \
  lib/libopenjdkjvmti.so \
  lib/libopenjdk.so \
  lib/libpac.so \
  lib/libprocinfo.so \
  lib/libprofile.so \
  lib/libvixl.so \
  lib64/libadbconnection.so \
  lib64/libandroidio.so \
  lib64/libartbase.so \
  lib64/libart-compiler.so \
  lib64/libart-dexlayout.so \
  lib64/libart-disassembler.so \
  lib64/libartpalette.so \
  lib64/libart.so \
  lib64/libdexfile_external.so \
  lib64/libdexfile.so \
  lib64/libdt_fd_forward.so \
  lib64/libdt_socket.so \
  lib64/libexpat.so \
  lib64/libjavacore.so \
  lib64/libjdwp.so \
  lib64/libmeminfo.so \
  lib64/libnativebridge.so \
  lib64/libnativehelper.so \
  lib64/libnativeloader.so \
  lib64/libnpt.so \
  lib64/libopenjdkjvm.so \
  lib64/libopenjdkjvmti.so \
  lib64/libopenjdk.so \
  lib64/libpac.so \
  lib64/libprocinfo.so \
  lib64/libprofile.so \
  lib64/libvixl.so \

PRIVATE_RUNTIME_APEX_DEPENDENCY_FILES := \
  bin/linker \
  bin/linker64 \
  lib/bionic/libc.so \
  lib/bionic/libdl.so \
  lib/bionic/libdl_android.so \
  lib/bionic/libm.so \
  lib64/bionic/libc.so \
  lib64/bionic/libdl.so \
  lib64/bionic/libdl_android.so \
  lib64/bionic/libm.so \

PRIVATE_CONSCRYPT_APEX_DEPENDENCY_LIBS := \
  lib/libcrypto.so \
  lib/libjavacrypto.so \
  lib/libssl.so \
  lib64/libcrypto.so \
  lib64/libjavacrypto.so \
  lib64/libssl.so \

PRIVATE_I18N_APEX_DEPENDENCY_LIBS := \
  lib/libandroidicu.so \
  lib/libicui18n.so \
  lib/libicu_jni.so \
  lib/libicuuc.so \
  lib64/libandroidicu.so \
  lib64/libicui18n.so \
  lib64/libicu_jni.so \
  lib64/libicuuc.so \

# Extracts files from an APEX into a location. The APEX can be either a .apex
# file in $(TARGET_OUT)/apex, or a directory in the same location. Files are
# extracted to $(TARGET_OUT) with the same relative paths as under the APEX
# root.
# $(1): APEX base name
# $(2): List of files to extract, with paths relative to the APEX root
#
# "cp -d" below doesn't work on Darwin, but this is only used for Golem builds
# and won't run on mac anyway.
define extract-from-apex
  apex_root=$(TARGET_OUT)/apex && \
  apex_file=$$apex_root/$(1).apex && \
  apex_dir=$$apex_root/$(1) && \
  if [ -f $$apex_file ]; then \
    rm -rf $$apex_dir && \
    mkdir -p $$apex_dir && \
    debugfs=$(HOST_OUT)/bin/debugfs_static && \
    $(HOST_OUT)/bin/deapexer --debugfs_path $$debugfs extract $$apex_file $$apex_dir; \
  fi && \
  for f in $(2); do \
    sf=$$apex_dir/$$f && \
    df=$(TARGET_OUT)/$$f && \
    if [ -f $$sf -o -h $$sf ]; then \
      mkdir -p $$(dirname $$df) && \
      cp -fd $$sf $$df; \
    fi || exit 1; \
  done
endef

# Copy or extract some required files from APEXes to the `system` (TARGET_OUT)
# directory. This is dangerous as these files could inadvertently stay in this
# directory and be included in a system image.
#
# This target is only used by Golem now.
#
# NB Android build does not use cp from:
#  $ANDROID_BUILD_TOP/prebuilts/build-tools/path/{linux-x86,darwin-x86}
# which has a non-standard set of command-line flags.
#
# TODO(b/129332183): Remove this when Golem has full support for the
# ART APEX.
.PHONY: standalone-apex-files
standalone-apex-files: deapexer \
                       $(RELEASE_ART_APEX) \
                       $(RUNTIME_APEX) \
                       $(CONSCRYPT_APEX) \
                       $(I18N_APEX)
	$(call extract-from-apex,$(RELEASE_ART_APEX),\
	  $(PRIVATE_ART_APEX_DEPENDENCY_LIBS) $(PRIVATE_ART_APEX_DEPENDENCY_FILES))
	# The Runtime APEX has the Bionic libs in ${LIB}/bionic subdirectories,
	# so we need to move them up a level after extraction.
	$(call extract-from-apex,$(RUNTIME_APEX),\
	  $(PRIVATE_RUNTIME_APEX_DEPENDENCY_FILES)) && \
	  for libdir in $(TARGET_OUT)/lib $(TARGET_OUT)/lib64; do \
	    if [ -d $$libdir/bionic ]; then \
	      mv -f $$libdir/bionic/*.so $$libdir; \
	    fi || exit 1; \
	  done
	$(call extract-from-apex,$(CONSCRYPT_APEX),\
	  $(PRIVATE_CONSCRYPT_APEX_DEPENDENCY_LIBS))
	$(call extract-from-apex,$(I18N_APEX),\
	  $(PRIVATE_I18N_APEX_DEPENDENCY_LIBS))

########################################################################
# Phony target for only building what go/lem requires for pushing ART on /data.

.PHONY: build-art-target-golem
# Also include libartbenchmark, we always include it when running golem.
# libstdc++ is needed when building for ART_TARGET_LINUX.

# Also include the Bionic libraries (libc, libdl, libdl_android, libm) and
# linker.
#
# TODO(b/129332183): Remove this when Golem has full support for the
# ART APEX.

# Also include:
# - a copy of the ICU prebuilt .dat file in /system/etc/icu on target
#   (see module `icu-data-art-test-i18n`); and
# so that it can be found even if the ART APEX is not available, by setting the
# environment variable `ART_TEST_ANDROID_ART_ROOT` to "/system" on device. This
# is a temporary change needed until Golem fully supports the ART APEX.
#
# TODO(b/129332183): Remove this when Golem has full support for the
# ART APEX.

# Also include:
# - a copy of the time zone data prebuilt files in
#   /system/etc/tzdata_module/etc/tz and /system/etc/tzdata_module/etc/icu
#   on target, (see modules `tzdata-art-test-tzdata`,
#   `tzlookup.xml-art-test-tzdata`, and `tz_version-art-test-tzdata`, and
#   `icu_overlay-art-test-tzdata`)
# so that they can be found even if the Time Zone Data APEX is not available,
# by setting the environment variable `ART_TEST_ANDROID_TZDATA_ROOT`
# to "/system/etc/tzdata_module" on device. This is a temporary change needed
# until Golem fully supports the Time Zone Data APEX.
#
# TODO(b/129332183): Remove this when Golem has full support for the
# ART APEX (and TZ Data APEX).

ART_TARGET_SHARED_LIBRARY_BENCHMARK := $(TARGET_OUT_SHARED_LIBRARIES)/libartbenchmark.so
build-art-target-golem: $(RELEASE_ART_APEX) com.android.runtime $(CONSCRYPT_APEX) \
                        $(TARGET_OUT_EXECUTABLES)/art \
                        $(TARGET_OUT_EXECUTABLES)/dex2oat_wrapper \
                        $(TARGET_OUT)/etc/public.libraries.txt \
                        $(ART_TARGET_SHARED_LIBRARY_BENCHMARK) \
                        libartpalette-system \
                        icu-data-art-test-i18n \
                        tzdata-art-test-tzdata tzlookup.xml-art-test-tzdata \
                        tz_version-art-test-tzdata icu_overlay-art-test-tzdata \
                        standalone-apex-files
	# remove debug libraries from public.libraries.txt because golem builds
	# won't have it.
	sed -i '/libartd.so/d' $(TARGET_OUT)/etc/public.libraries.txt
	sed -i '/libdexfiled.so/d' $(TARGET_OUT)/etc/public.libraries.txt
	sed -i '/libprofiled.so/d' $(TARGET_OUT)/etc/public.libraries.txt
	sed -i '/libartbased.so/d' $(TARGET_OUT)/etc/public.libraries.txt
	# The 'art' script will look for a 'com.android.art' directory.
	ln -sf com.android.art.release $(TARGET_OUT)/apex/com.android.art

########################################################################
# Phony target for building what go/lem requires on host.
.PHONY: build-art-host-golem
# Also include libartbenchmark, we always include it when running golem.
ART_HOST_SHARED_LIBRARY_BENCHMARK := $(ART_HOST_OUT_SHARED_LIBRARIES)/libartbenchmark.so
build-art-host-golem: build-art-host \
                      $(ART_HOST_SHARED_LIBRARY_BENCHMARK) \
                      $(HOST_OUT_EXECUTABLES)/dex2oat_wrapper

########################################################################
# Phony target for building what go/lem requires for syncing /system to target.
.PHONY: build-art-unbundled-golem
art_apex_jars := $(foreach pair,$(ART_APEX_JARS), $(call word-colon,2,$(pair)))
build-art-unbundled-golem: art-runtime linker oatdump $(art_apex_jars) conscrypt crash_dump

########################################################################
# Rules for building all dependencies for tests.

.PHONY: build-art-host-tests
build-art-host-tests:   build-art-host $(TEST_ART_RUN_TEST_DEPENDENCIES) $(ART_TEST_HOST_RUN_TEST_DEPENDENCIES) $(ART_TEST_HOST_GTEST_DEPENDENCIES) | $(TEST_ART_RUN_TEST_ORDERONLY_DEPENDENCIES)

.PHONY: build-art-target-tests
build-art-target-tests:   build-art-target $(TEST_ART_RUN_TEST_DEPENDENCIES) $(ART_TEST_TARGET_RUN_TEST_DEPENDENCIES) $(ART_TEST_TARGET_GTEST_DEPENDENCIES) | $(TEST_ART_RUN_TEST_ORDERONLY_DEPENDENCIES)

########################################################################
# targets to switch back and forth from libdvm to libart

.PHONY: use-art
use-art:
	$(ADB) root
	$(ADB) wait-for-device shell stop
	$(ADB) shell setprop persist.sys.dalvik.vm.lib.2 libart.so
	$(ADB) shell start

.PHONY: use-artd
use-artd:
	$(ADB) root
	$(ADB) wait-for-device shell stop
	$(ADB) shell setprop persist.sys.dalvik.vm.lib.2 libartd.so
	$(ADB) shell start

.PHONY: use-dalvik
use-dalvik:
	$(ADB) root
	$(ADB) wait-for-device shell stop
	$(ADB) shell setprop persist.sys.dalvik.vm.lib.2 libdvm.so
	$(ADB) shell start

.PHONY: use-art-full
use-art-full:
	$(ADB) root
	$(ADB) wait-for-device shell stop
	$(ADB) shell rm -rf $(ART_TARGET_DALVIK_CACHE_DIR)/*
	$(ADB) shell setprop dalvik.vm.dex2oat-filter \"\"
	$(ADB) shell setprop dalvik.vm.image-dex2oat-filter \"\"
	$(ADB) shell setprop persist.sys.dalvik.vm.lib.2 libart.so
	$(ADB) shell setprop dalvik.vm.usejit false
	$(ADB) shell start

.PHONY: use-artd-full
use-artd-full:
	$(ADB) root
	$(ADB) wait-for-device shell stop
	$(ADB) shell rm -rf $(ART_TARGET_DALVIK_CACHE_DIR)/*
	$(ADB) shell setprop dalvik.vm.dex2oat-filter \"\"
	$(ADB) shell setprop dalvik.vm.image-dex2oat-filter \"\"
	$(ADB) shell setprop persist.sys.dalvik.vm.lib.2 libartd.so
	$(ADB) shell setprop dalvik.vm.usejit false
	$(ADB) shell start

.PHONY: use-art-jit
use-art-jit:
	$(ADB) root
	$(ADB) wait-for-device shell stop
	$(ADB) shell rm -rf $(ART_TARGET_DALVIK_CACHE_DIR)/*
	$(ADB) shell setprop dalvik.vm.dex2oat-filter "verify-at-runtime"
	$(ADB) shell setprop dalvik.vm.image-dex2oat-filter "verify-at-runtime"
	$(ADB) shell setprop persist.sys.dalvik.vm.lib.2 libart.so
	$(ADB) shell setprop dalvik.vm.usejit true
	$(ADB) shell start

.PHONY: use-art-interpret-only
use-art-interpret-only:
	$(ADB) root
	$(ADB) wait-for-device shell stop
	$(ADB) shell rm -rf $(ART_TARGET_DALVIK_CACHE_DIR)/*
	$(ADB) shell setprop dalvik.vm.dex2oat-filter "interpret-only"
	$(ADB) shell setprop dalvik.vm.image-dex2oat-filter "interpret-only"
	$(ADB) shell setprop persist.sys.dalvik.vm.lib.2 libart.so
	$(ADB) shell setprop dalvik.vm.usejit false
	$(ADB) shell start

.PHONY: use-artd-interpret-only
use-artd-interpret-only:
	$(ADB) root
	$(ADB) wait-for-device shell stop
	$(ADB) shell rm -rf $(ART_TARGET_DALVIK_CACHE_DIR)/*
	$(ADB) shell setprop dalvik.vm.dex2oat-filter "interpret-only"
	$(ADB) shell setprop dalvik.vm.image-dex2oat-filter "interpret-only"
	$(ADB) shell setprop persist.sys.dalvik.vm.lib.2 libartd.so
	$(ADB) shell setprop dalvik.vm.usejit false
	$(ADB) shell start

.PHONY: use-art-verify-none
use-art-verify-none:
	$(ADB) root
	$(ADB) wait-for-device shell stop
	$(ADB) shell rm -rf $(ART_TARGET_DALVIK_CACHE_DIR)/*
	$(ADB) shell setprop dalvik.vm.dex2oat-filter "verify-none"
	$(ADB) shell setprop dalvik.vm.image-dex2oat-filter "verify-none"
	$(ADB) shell setprop persist.sys.dalvik.vm.lib.2 libart.so
	$(ADB) shell setprop dalvik.vm.usejit false
	$(ADB) shell start

########################################################################

# Clear locally used variables.
TEST_ART_TARGET_SYNC_DEPS :=

# Helper target that depends on boot image creation.
#
# Can be used, for example, to dump initialization failures:
#   m art-boot-image ART_BOOT_IMAGE_EXTRA_ARGS=--dump-init-failures=fails.txt
.PHONY: art-boot-image
art-boot-image:  $(DEXPREOPT_IMAGE_boot_$(TARGET_ARCH))

.PHONY: art-job-images
art-job-images: \
  art-boot-image \
  $(2ND_DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME) \
  $(HOST_OUT_EXECUTABLES)/dex2oats \
  $(HOST_OUT_EXECUTABLES)/dex2oatds \
  $(HOST_OUT_EXECUTABLES)/profman
