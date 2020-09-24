ARCH=x64

ICU_FILTER = $(TOP)/icu-filters/icudt.json
ICU_VER = 67

ANDROID_API=21
ANDROID_FLAGS=-m64 -fstack-protector
ANDROID_PLATFORM=x86_64

ifeq ($(ARCH),x86)
	ANDROID_FLAGS=-m32 -fstack-protector
	ANDROID_PLATFORM=i686
endif
ifeq ($(ARCH),arm64)
	ANDROID_FLAGS=-fpic -fstack-protector
	ANDROID_PLATFORM=aarch64
endif
ifeq ($(ARCH),arm)
	ANDROID_FLAGS=-march=armv7-a -mtune=cortex-a8 -mfpu=vfp -mfloat-abi=softfp -fpic -fstack-protector
	ANDROID_PLATFORM=armv5
endif

all: icu-android

TOP = $(CURDIR)/../
HOST_BUILDDIR = $(TOP)/artifacts/obj/icu-host
HOST_BINDIR = $(TOP)/artifacts/bin/icu-host
ANDROID_BUILDDIR = $(TOP)/artifacts/obj/icu-android-$(ARCH)
ANDROID_BINDIR = $(TOP)/artifacts/bin/icu-android-$(ARCH)
ANDROID_NDK=$(ANDROID_NDK_ROOT)

$(HOST_BUILDDIR):
	mkdir -p $@

.PHONY: host
host: $(HOST_BUILDDIR)/.stamp-host

$(HOST_BUILDDIR)/.stamp-host: $(HOST_BUILDDIR)/.stamp-configure-host
	cd $(HOST_BUILDDIR) && $(MAKE) -j8 all && $(MAKE) install
	touch $@

$(HOST_BUILDDIR)/.stamp-configure-host: | $(HOST_BUILDDIR)
	cd $(HOST_BUILDDIR) && $(TOP)/icu/icu4c/source/configure \
	--prefix=$(HOST_BINDIR) --disable-icu-config --disable-extras --disable-tests --disable-samples
	touch $@

$(ANDROID_BUILDDIR):
	mkdir -p $@

.PHONY: icu-android
icu-android: $(ANDROID_BUILDDIR)/.stamp-configure-android
	cd $(ANDROID_BUILDDIR) && $(MAKE) -j8 all && $(MAKE) install
	cp $(ANDROID_BUILDDIR)/data/out/icudt$(ICU_VER)l.dat $(ANDROID_BINDIR)/$(basename $(notdir $(ICU_FILTER))).dat

# Disable some features we don't need, see icu/icu4c/source/common/unicode/uconfig.h 
ICU_DEFINES= \
	-DUCONFIG_NO_FILTERED_BREAK_ITERATION=1 \
	-DUCONFIG_NO_REGULAR_EXPRESSIONS=1 \
	-DUCONFIG_NO_TRANSLITERATION=1 \
	-DUCONFIG_NO_FILE_IO=1 \
	-DU_CHARSET_IS_UTF8=1 \
	-DU_CHECK_DYLOAD=0 \
	-DU_ENABLE_DYLOAD=0

CONFIGURE_ADD_ARGS=
ifeq ($(ICU_TRACING),true)
	CONFIGURE_ADD_ARGS += --enable-tracing
endif

$(ANDROID_BUILDDIR)/.stamp-configure-android: $(ICU_FILTER) $(HOST_BUILDDIR)/.stamp-host | $(ANDROID_BUILDDIR)
	rm -rf $(ANDROID_BUILDDIR)/data/out/tmp
	cd $(ANDROID_BUILDDIR) && \
	ICU_DATA_FILTER_FILE=$(ICU_FILTER) \
	$(TOP)/icu/icu4c/source/configure \
	--prefix=$(ANDROID_BINDIR) \
	--host=$(ANDROID_PLATFORM)-linux-android \
	--enable-static \
	--disable-shared \
	--disable-tests \
	--disable-extras \
	--disable-samples \
	--disable-icuio \
	--disable-renaming \
	--disable-icu-config \
	--disable-strict \
	--disable-layout \
	--disable-layoutex \
	--disable-tools \
	--disable-dyload \
	--with-cross-build=$(HOST_BUILDDIR) \
	--with-data-packaging=archive \
	$(CONFIGURE_ADD_ARGS) \
	CFLAGS="-Os $(ANDROID_FLAGS) -I$(ANDROID_NDK_ROOT)/sysroot/usr/include -I$(ANDROID_NDK_ROOT)/sysroot/usr/include/$(ANDROID_PLATFORM)-linux-android" \
    CXXFLAGS="-Os $(ANDROID_FLAGS) -I$(ANDROID_NDK_ROOT)/sysroot/usr/include -I$(ANDROID_NDK_ROOT)/sysroot/usr/include/$(ANDROID_PLATFORM)-linux-android" \
    CC="$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/darwin-$(ANDROID_PLATFORM)/bin/$(ANDROID_PLATFORM)-linux-android$(ANDROID_API)-clang" \
    CXX="$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/darwin-$(ANDROID_PLATFORM)/bin/$(ANDROID_PLATFORM)-linux-android$(ANDROID_API)-clang++" \
    AR="$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/darwin-$(ANDROID_PLATFORM)/bin/$(ANDROID_PLATFORM)-linux-android-ar" \
    RANLIB="$(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/darwin-$(ANDROID_PLATFORM)/bin/$(ANDROID_PLATFORM)-linux-android-ranlib"
