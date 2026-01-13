# ==============================================================================
# GnuCOBOL Multi-Target Build (WASI & Emscripten) - SJLJ FIXED
# ==============================================================================

PWD            := $(shell pwd)
DIST           := $(PWD)/dist
DEPS_SRC_GMP    := $(PWD)/gmp-6.3.0
DEPS_SRC_COBOL  := $(PWD)/gnucobol-3.2
FIX_HEADER      := $(PWD)/wasi_fix.h

WASI_OUT       := $(DIST)/wasi
EMS_OUT        := $(DIST)/emscripten

# --- WASI Config ---
WASI_SDK_PATH  ?= /opt/wasi-sdk
WASI_CC         := $(WASI_SDK_PATH)/bin/clang
WASI_SYSROOT    := $(WASI_SDK_PATH)/share/wasi-sysroot
# WASI_LIB_DIR    := $(WASI_SYSROOT)/lib/wasm32-wasi
WASI_LIB_DIR    := $(WASI_SYSROOT)/lib/wasm32-wasip1-threads

WASI_ENV := CC="$(WASI_CC)" LD="$(WASI_SDK_PATH)/bin/wasm-ld" AR="$(WASI_SDK_PATH)/bin/llvm-ar" \
            NM="$(WASI_SDK_PATH)/bin/llvm-nm" RANLIB="$(WASI_SDK_PATH)/bin/llvm-ranlib" \
            STRIP="$(WASI_SDK_PATH)/bin/llvm-strip" \
            ac_cv_header_signal_h=yes ac_cv_func_system=yes ac_cv_func_getopt_long=yes \
            ac_cv_func_fork=no ac_cv_func_vfork=no ac_cv_func_kill=no

WASI_CONF_CPPFLAGS := --sysroot=$(WASI_SYSROOT)
WASI_CONF_LDFLAGS  := --sysroot=$(WASI_SYSROOT)

# Features required for threads/shared memory
WASM_FEATURES = -matomics -mbulk-memory -pthread

# Flags for Actual Compilation - Crucial: SJLJ must be in CFLAGS
# Use the native Wasm Exception Handling proposal
WASI_REAL_CFLAGS   := -O2 -mllvm -wasm-enable-sjlj -fsigned-char -fwasm-exceptions $(WASM_FEATURES)
WASI_REAL_CPPFLAGS := --sysroot=$(WASI_SYSROOT) -I$(WASI_OUT)/include \
                     -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_GETPID \
                     -D_WASI_EMULATED_MMAN -include $(FIX_HEADER)
# Get the path to the clang builtins library for this specific SDK
CLANG_RTLIB := $(shell $(WASI_CC) -print-libgcc-file-name)
WASI_REAL_LDFLAGS  := --sysroot=$(WASI_SYSROOT) -L$(WASI_OUT)/lib -L$(WASI_LIB_DIR) \
		     -Wl,--allow-undefined,-mllvm,-wasm-enable-sjlj \
 		     -lsetjmp -Wl,--shared-memory -pthread -Wl,--initial-memory=67108864 -Wl,--max-memory=2147483648
# WASI_REAL_LIBS     := $(WASI_LIB_DIR)/libwasi-emulated-signal.a \
#                      $(WASI_LIB_DIR)/libwasi-emulated-getpid.a \
#                      $(WASI_LIB_DIR)/libwasi-emulated-mman.a
WASI_REAL_LIBS     := -lwasi-emulated-signal -lwasi-emulated-getpid -lwasi-emulated-mman

# --- Emscripten Config ---
EMCC_OPTS := -s WASM=1 -s FORCE_FILESYSTEM=1 -s ALLOW_MEMORY_GROWTH=1 \
             -s INITIAL_MEMORY=128MB -s EXIT_RUNTIME=1 \
             -s EXPORTED_RUNTIME_METHODS='["FS", "callMain"]' \
             -s INVOKE_RUN=0 -O2

.PHONY: all clean wasi emscripten check-fix

all: wasi emscripten

# ==============================================================================
# TARGET: WASI
# ==============================================================================

wasi: $(WASI_OUT)/bin/cobc.wasm

$(WASI_OUT)/lib/libgmp.a:
	mkdir -p $(WASI_OUT)
	cd $(DEPS_SRC_GMP) && $(WASI_ENV) ./configure --host=wasm32-wasi \
		--build=x86_64-linux --disable-assembly --prefix=$(WASI_OUT) \
		CPPFLAGS="$(WASI_CONF_CPPFLAGS)" LDFLAGS="$(WASI_CONF_LDFLAGS)"
	$(MAKE) -C $(DEPS_SRC_GMP) install \
		CPPFLAGS="$(WASI_REAL_CPPFLAGS)" CFLAGS="$(WASI_REAL_CFLAGS)" LIBS="$(WASI_REAL_LIBS)" LDFLAGS="$(WASI_REAL_LDFLAGS)"

$(WASI_OUT)/bin/cobc.wasm: $(WASI_OUT)/lib/libgmp.a
	cd $(DEPS_SRC_COBOL) && $(WASI_ENV) ./configure --host=wasm32-wasi \
		--build=x86_64-linux --without-db --prefix=$(WASI_OUT) \
		--with-gmp=$(WASI_OUT) \
		--disable-shared --enable-static \
		--with-vfork=no --with-fork=no \
		ac_cv_func_getlogin=no \
		CPPFLAGS="$(WASI_CONF_CPPFLAGS) -I$(WASI_OUT)/include" \
		LDFLAGS="$(WASI_CONF_LDFLAGS) -L$(WASI_OUT)/lib" HELP2MAN=/bin/true
	find $(DEPS_SRC_COBOL) -name "Makefile" -exec sed -i 's/,-z,relro//g' {} +
	find $(DEPS_SRC_COBOL) -name "Makefile" -exec sed -i 's/,-z,now//g' {} +
	# Pass WASI_REAL_CFLAGS to all sub-makes to ensure SJLJ support
	$(MAKE) -C $(DEPS_SRC_COBOL)/lib CPPFLAGS="$(WASI_REAL_CPPFLAGS) -I$(DEPS_SRC_COBOL)" CFLAGS="$(WASI_REAL_CFLAGS)"
	$(MAKE) -C $(DEPS_SRC_COBOL)/libcob install CPPFLAGS="$(WASI_REAL_CPPFLAGS)" CFLAGS="$(WASI_REAL_CFLAGS)"
	$(MAKE) -C $(DEPS_SRC_COBOL)/cobc CPPFLAGS="$(WASI_REAL_CPPFLAGS) -I$(DEPS_SRC_COBOL)" \
		CFLAGS="$(WASI_REAL_CFLAGS)" LDFLAGS="$(WASI_REAL_LDFLAGS)" \
		LIBS="$(WASI_REAL_LIBS) $(WASI_OUT)/lib/libgmp.a"
	mkdir -p $(WASI_OUT)/bin && cp $(DEPS_SRC_COBOL)/cobc/cobc $@
	cp $(DEPS_SRC_COBOL)/libcob.h $(WASI_OUT)/include/
	cp -r /usr/share/gnucobol $(WASI_OUT)/share/

# ==============================================================================
# TARGET: EMSCRIPTEN
# ==============================================================================

emscripten: $(EMS_OUT)/bin/cobc.js

$(EMS_OUT)/lib/libgmp.a:
	mkdir -p $(EMS_OUT)
	-$(MAKE) -C $(DEPS_SRC_GMP) distclean
	cd $(DEPS_SRC_GMP) && emconfigure ./configure --host=none --build=none --disable-assembly --prefix=$(EMS_OUT)
	$(MAKE) -C $(DEPS_SRC_GMP) install

$(EMS_OUT)/bin/cobc.js: $(EMS_OUT)/lib/libgmp.a
	-$(MAKE) -C $(DEPS_SRC_COBOL) distclean
	cd $(DEPS_SRC_COBOL) && emconfigure ./configure --host=none --build=none --without-db \
		--disable-shared --enable-static --disable-nls --prefix=$(EMS_OUT) \
		--with-gmp=$(EMS_OUT) CPPFLAGS="-I$(EMS_OUT)/include" LDFLAGS="-L$(EMS_OUT)/lib" HELP2MAN=/bin/true
	find $(DEPS_SRC_COBOL) -name "Makefile" -exec sed -i 's/,-z,relro//g' {} +
	find $(DEPS_SRC_COBOL) -name "Makefile" -exec sed -i 's/,-z,now//g' {} +
	$(MAKE) -C $(DEPS_SRC_COBOL)/lib CPPFLAGS="-I$(EMS_OUT)/include -I$(DEPS_SRC_COBOL)"
	$(MAKE) -C $(DEPS_SRC_COBOL)/libcob install CPPFLAGS="-I$(EMS_OUT)/include"
	$(MAKE) -C $(DEPS_SRC_COBOL)/cobc CPPFLAGS="-I$(EMS_OUT)/include -I$(DEPS_SRC_COBOL)"
	mkdir -p $(EMS_OUT)/bin
	emcc $(DEPS_SRC_COBOL)/cobc/*.o $(DEPS_SRC_COBOL)/lib/*.o \
		$(EMCC_OPTS) -L$(EMS_OUT)/lib -lcob -lgmp -o $@
	cp $(DEPS_SRC_COBOL)/libcob.h $(EMS_OUT)/include/

clean:
	-$(MAKE) -C $(DEPS_SRC_GMP) clean
	-$(MAKE) -C $(DEPS_SRC_COBOL) clean
	rm -rf $(DIST)
