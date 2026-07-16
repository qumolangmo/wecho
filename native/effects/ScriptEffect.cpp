#include "effect.hpp"
#include "../scripting/wecho_dsp_c_api.h"
#include <dlfcn.h>
#include <fstream>
#include <sstream>
#include <csetjmp>
#include <csignal>

static void registerAllSymbols(TCCState* state) {
    struct { const char* name; void* addr; } syms[] = {
        /* math */
        {"_math_sin",    (void*)&_math_sin},
        {"_math_sinh",   (void*)&_math_sinh},
        {"_math_cos",    (void*)&_math_cos},
        {"_math_cosh",   (void*)&_math_cosh},
        {"_math_tan",    (void*)&_math_tan},
        {"_math_tanh",   (void*)&_math_tanh},
        {"_math_atan",   (void*)&_math_atan},
        {"_math_atanh",  (void*)&_math_atanh},
        {"_math_exp",    (void*)&_math_exp},
        {"_math_log",    (void*)&_math_log},
        {"_math_log2",   (void*)&_math_log2},
        {"_math_log10",  (void*)&_math_log10},
        {"_math_pow",    (void*)&_math_pow},
        {"_math_sqrt",   (void*)&_math_sqrt},
        {"_math_fabs",   (void*)&_math_fabs},
        {"_math_fmod",   (void*)&_math_fmod},
        {"_math_floor",  (void*)&_math_floor},
        {"_math_ceil",   (void*)&_math_ceil},
        {"_math_fmin",   (void*)&_math_fmin},
        {"_math_fmax",   (void*)&_math_fmax},
        /* biquad */
        {"new_biquad",            (void*)&new_biquad},
        {"biquad_reset",          (void*)&biquad_reset},
        {"biquad_set_hp",         (void*)&biquad_set_hp},
        {"biquad_set_lp",         (void*)&biquad_set_lp},
        {"biquad_set_peak",       (void*)&biquad_set_peak},
        {"biquad_set_ls",         (void*)&biquad_set_ls},
        {"biquad_set_hs",         (void*)&biquad_set_hs},
        {"biquad_set_coeffs",     (void*)&biquad_set_coeffs},
        {"biquad_process",        (void*)&biquad_process},
        {"biquad_process_block",  (void*)&biquad_process_block},
        /* delay line */
        {"new_delay_line",            (void*)&new_delay_line},
        {"delay_line_reset",          (void*)&delay_line_reset},
        {"delay_line_set_delay",      (void*)&delay_line_set_delay},
        {"delay_line_process",        (void*)&delay_line_process},
        {"delay_line_process_block",  (void*)&delay_line_process_block},
        {"delay_line_read",           (void*)&delay_line_read},
        {"delay_line_read_block",     (void*)&delay_line_read_block},
        {"delay_line_write",          (void*)&delay_line_write},
        {"delay_line_write_block",    (void*)&delay_line_write_block},
        /* convolver */
        {"new_convolver",           (void*)&new_convolver},
        {"convolver_reset",         (void*)&convolver_reset},
        {"convolver_set_ir",        (void*)&convolver_set_ir},
        {"convolver_set_ir_path",   (void*)&convolver_set_ir_path},
        {"convolver_process_block", (void*)&convolver_process_block},
        /* harmonic */
        {"new_harmonic",           (void*)&new_harmonic},
        {"harmonic_reset",         (void*)&harmonic_reset},
        {"harmonic_set_coeffs",    (void*)&harmonic_set_coeffs},
        {"harmonic_process",       (void*)&harmonic_process},
        {"harmonic_process_block", (void*)&harmonic_process_block},
        /* tcclib.h */
        {"memset",                 (void*)&memset},
        {"memcpy",                 (void*)&memcpy},
        {"memmove",                (void*)&memmove},
    };
    for (auto& s : syms) {
        tcc_add_symbol(state, s.name, s.addr);
    }
}

std::string ScriptEffect::last_error;
static std::string g_cache_dir;

/* crash recovery variables */
static sigjmp_buf g_script_jmp_buf;
static volatile bool g_script_crashed = false;
static struct sigaction g_old_sigsegv_handler;
static struct sigaction g_old_sigbus_handler;
static struct sigaction sa;

static void script_crash_handler(int sig) {
    g_script_crashed = true;
    siglongjmp(g_script_jmp_buf, 1);
}

bool ScriptEffect::consumeCrashFlag() {
    if (g_script_crashed) {
        g_script_crashed = false;
        return true;
    }
    return false;
}

static std::string g_libtcc1_path;
static std::string g_tcclib_h;
static std::string g_wecho_dsp_c_api_h;

void ScriptEffect::setCacheDir(std::string_view cache_dir) {
    g_cache_dir = std::string(cache_dir);
}

std::string ScriptEffect::getLastError() { 
    return last_error; 
}

std::string_view ScriptEffect::getCacheDir() {
    return g_cache_dir;
}

static std::string readFile(const char* path) {
    std::ifstream file(path);

    if (!file.is_open()) {
        return "";
    }
    
    std::stringstream ss;

    ss << file.rdbuf();
    
    return ss.str();
}

static void ensureTccAssetsAvailable() {
    if (!g_libtcc1_path.empty()) {
        return;
    }

    std::string cacheDir = g_cache_dir;

    g_libtcc1_path = std::string(cacheDir) + "/libtcc1.a";
    g_tcclib_h = readFile((std::string(cacheDir) + "/tcclib.h").c_str());
    g_wecho_dsp_c_api_h = readFile((std::string(cacheDir) + "/wecho_dsp_c_api.h").c_str());
}

static std::string cleanCode(const std::string& code) {
    std::string result;
    result.reserve(code.size());
    for (char c : code) {
        if (c == '\t' || c == '\n' || c == '\r') {
            result += c;
        } else if (c >= 32 && c < 127) {
            result += c;
        } else if (c == ' ' || c == '\0') {
            result += ' ';
        }
    }
    return result;
}

static std::string prependHeaders(const std::string& userCode) {
    std::string result;
    std::string cleaned = cleanCode(userCode);
    result.reserve(g_tcclib_h.size() + g_wecho_dsp_c_api_h.size() + cleaned.size() + 64);
    result += g_tcclib_h;
    result += g_wecho_dsp_c_api_h;
    result += "\n#line 1 \"user_script.c\"\n";
    result += cleaned;
    return result;
}

ScriptEffect::ScriptEffect(bool enabled)
    : Effect(enabled)
    , state(nullptr)
    , is_loaded(false)
    , crashed(false)
    , process_func(nullptr)
    , params_func(nullptr) {

    sa.sa_handler = script_crash_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
}

inline void ScriptEffect::errorHandle(void* op, const char* error_msg) {
    last_error = error_msg;
    LOG_D("ScriptEffect error: %s", error_msg);
}

ScriptEffect::~ScriptEffect() {
    while (spin_lock.test_and_set(std::memory_order_acquire));

    TCCState* old_state = state;
    state = nullptr;
    process_func = nullptr;
    params_func = nullptr;
    is_loaded.store(false, std::memory_order_release);

    cleanupAllocations();

    spin_lock.clear(std::memory_order_release);

    if (old_state) {
        tcc_delete(old_state);
    }
}

void ScriptEffect::cleanupAllocations() {
    for (auto& item : allocations) {
        switch (item.type) {
            case BiquadType: {
                if (item.data != nullptr) {
                    delete (CBiquad*)item.data;
                    item.data = nullptr;
                }
                break;
            }
            case DelayLineType: {
                if (item.data != nullptr) {
                    delete (CDelayLine*)item.data;
                    item.data = nullptr;
                }
                break;
            }
            case ConvolverType: {
                if (item.data != nullptr) {
                    delete (CConvolver*)item.data;
                    item.data = nullptr;
                }
                break;
            }
            case HarmonicType: {
                if (item.data != nullptr) {
                    delete (CHarmonic*)item.data;
                    item.data = nullptr;
                }   
                break;
            }
        }
    }

    LOG_D("ScriptEffect::cleanupAllocations done, allocations=%zu", allocations.size());
    allocations.clear();
}

void ScriptEffect::setCode(std::string code) {
    last_error.clear();
    crashed.store(false, std::memory_order_release);

    if (code.empty()) {
        while (spin_lock.test_and_set(std::memory_order_acquire));

        is_loaded.store(false, std::memory_order_release);
        this->code.clear();
        process_func = nullptr;
        params_func = nullptr;

        TCCState* old_state = state;
        state = nullptr;

        cleanupAllocations();

        spin_lock.clear(std::memory_order_release);

        if (old_state) {
            tcc_delete(old_state);
        }

        return;
    } else if (code == this->code) {
        return;
    }

    TCCState* new_state = tcc_new();
    tcc_set_output_type(new_state, TCC_OUTPUT_MEMORY);
    tcc_set_error_func(new_state, nullptr, ScriptEffect::errorHandle);

    ensureTccAssetsAvailable();

    std::string cacheDir = g_cache_dir;

    tcc_add_include_path(new_state, (cacheDir + "/include").c_str());
    tcc_set_lib_path(new_state, cacheDir.c_str());
    tcc_set_options(new_state, "-std=c99 -nostdlib -DTCC_MATH");
    tcc_add_library_path(new_state, "/system/lib64");
    tcc_add_library(new_state, "dl");

    std::string fullCode = prependHeaders(code);

    if (tcc_compile_string(new_state, fullCode.c_str()) == -1) {
        tcc_delete(new_state);
        is_loaded.store(false, std::memory_order_release);
        return;
    }

    tcc_add_file(new_state, g_libtcc1_path.c_str());
    registerAllSymbols(new_state);

    if (tcc_relocate(new_state) == -1) {
        tcc_delete(new_state);
        is_loaded.store(false, std::memory_order_release);
        return;
    }

    auto run_handle = tcc_get_symbol(new_state, "run");
    auto params_handle = tcc_get_symbol(new_state, "setParams");

    if (!run_handle || !params_handle) {
        tcc_delete(new_state);
        is_loaded.store(false, std::memory_order_release);
        return;
    }

    auto new_process_func = (void (*)(float*, float*, float*, float*))run_handle;
    auto new_params_func = (void (*)(ScriptParams*))params_handle;

    while (spin_lock.test_and_set(std::memory_order_acquire));

    TCCState* old_state = state;

    state = new_state;
    process_func = new_process_func;
    params_func = new_params_func;
    this->code = std::move(code);
    is_loaded.store(true, std::memory_order_release);

    cleanupAllocations();

    extern void _wecho_dsp_begin_allocations(std::vector<AllocatedStructure>*);
    extern void _wecho_dsp_end_allocations();

    _wecho_dsp_begin_allocations(&allocations);
    new_params_func(params);
    _wecho_dsp_end_allocations();

    extern const char* _get_c_api_error();
    extern void _clear_c_api_error();

    const char* c_error = _get_c_api_error();

    if (c_error && c_error[0] != '\0') {
        last_error = std::string("Runtime error during init: ") + c_error;

        is_loaded.store(false, std::memory_order_release);
        process_func = nullptr;
        params_func = nullptr;
        state = nullptr;

        cleanupAllocations();

        spin_lock.clear(std::memory_order_release);

        if (old_state) {
            tcc_delete(old_state);
        }

        _clear_c_api_error();
        return;
    }

    spin_lock.clear(std::memory_order_release);

    if (old_state) {
        tcc_delete(old_state);
    }
}

void ScriptEffect::setParams(ScriptParamsArray params) {
    while (spin_lock.test_and_set(std::memory_order_acquire));

    std::memcpy(this->params, params, sizeof(ScriptParamsArray));
    cleanupAllocations();

    if (is_loaded.load(std::memory_order_acquire) && params_func) {
        extern void _wecho_dsp_begin_allocations(std::vector<struct AllocatedStructure>*);
        extern void _wecho_dsp_end_allocations();

        _wecho_dsp_begin_allocations(&allocations);
        params_func(this->params);
        _wecho_dsp_end_allocations();
    }

    spin_lock.clear(std::memory_order_release);
}

void ScriptEffect::run(std::vector<std::vector<float>>& audio) {
    if (!is_loaded.load(std::memory_order_acquire) 
        || crashed.load(std::memory_order_acquire)) {
        return;
    }

    while (spin_lock.test_and_set(std::memory_order_acquire));

    auto func = process_func;

    if (!func) {
        spin_lock.clear(std::memory_order_release);
        return;
    }

    sigaction(SIGSEGV, &sa, &g_old_sigsegv_handler);
    sigaction(SIGBUS, &sa, &g_old_sigbus_handler);

    g_script_crashed = false;

    if (sigsetjmp(g_script_jmp_buf, 1) == 0) {
        func(audio[0].data(), audio[1].data(), audio[0].data(), audio[1].data());
        spin_lock.clear(std::memory_order_release);
    } else {
        /* crash: siglongjmp */
        spin_lock.clear(std::memory_order_release);
        crashed.store(true, std::memory_order_release);
        is_loaded.store(false, std::memory_order_release);
        LOG_D("ScriptEffect: runtime crash detected, script disabled");
        last_error = "Runtime crash (SIGSEGV/SIGBUS). Script has been disabled.\n"
        "Check for buffer overflows or invalid pointer access.\n"
        "Please change current dsp code to another one (to avoid the next restart crash), and restart wecho.";
    }

    /* restore original handlers */
    sigaction(SIGSEGV, &g_old_sigsegv_handler, nullptr);
    sigaction(SIGBUS, &g_old_sigbus_handler, nullptr);
}

void ScriptEffect::copyParamsFrom(const ScriptEffect& other) {
    reset();

    std::memcpy(params, other.params, sizeof(params));

    this->setCode(other.code);
    this->setParams(params);
    this->setEnabled(other.isEnabled());
}

Priority ScriptEffect::priority() const {
    return Priority::SCRIPT_EFFECT;
}

void ScriptEffect::reset() {
    last_error.clear();

    while (spin_lock.test_and_set(std::memory_order_acquire));

    code.clear();

    TCCState* old_state = state;
    state = nullptr;

    is_loaded.store(false, std::memory_order_release);
    crashed.store(false, std::memory_order_release);
    process_func = nullptr;
    params_func = nullptr;

    std::memset(params, 0, sizeof(params));

    cleanupAllocations();

    spin_lock.clear(std::memory_order_release);

    if (old_state) {
        tcc_delete(old_state);
    }
}
