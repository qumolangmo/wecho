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
        {"get_biquad",            (void*)&get_biquad},
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
        {"get_delay_line",            (void*)&get_delay_line},
        {"delay_line_reset",          (void*)&delay_line_reset},
        {"delay_line_set_delay",      (void*)&delay_line_set_delay},
        {"delay_line_process",        (void*)&delay_line_process},
        {"delay_line_process_block",  (void*)&delay_line_process_block},
        {"delay_line_read",           (void*)&delay_line_read},
        {"delay_line_read_block",     (void*)&delay_line_read_block},
        {"delay_line_write",          (void*)&delay_line_write},
        {"delay_line_write_block",    (void*)&delay_line_write_block},
        /* convolver */
        {"get_convolver",           (void*)&get_convolver},
        {"convolver_reset",         (void*)&convolver_reset},
        {"convolver_set_ir",        (void*)&convolver_set_ir},
        {"convolver_set_ir_path",   (void*)&convolver_set_ir_path},
        {"convolver_process_block", (void*)&convolver_process_block},
        /* harmonic */
        {"get_harmonic",           (void*)&get_harmonic},
        {"harmonic_reset",         (void*)&harmonic_reset},
        {"harmonic_set_coeffs",    (void*)&harmonic_set_coeffs},
        {"harmonic_process",       (void*)&harmonic_process},
        {"harmonic_process_block", (void*)&harmonic_process_block},
        /* tcclib.h */
        {"memset",                 (void*)&memset},
        {"memcpy",                 (void*)&memcpy},
    };
    for (auto& s : syms) {
        tcc_add_symbol(state, s.name, s.addr);
    }
}

std::string ScriptEffect::last_error;
static std::string g_cache_dir;

// crash recovery
static sigjmp_buf g_script_jmp_buf;
static volatile bool g_script_crashed = false;
static struct sigaction g_old_sigsegv_handler;
static struct sigaction g_old_sigbus_handler;

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
    , params_func(nullptr) {}

inline void ScriptEffect::errorHandle(void* op, const char* error_msg) {
    last_error = error_msg;
    LOG_D("ScriptEffect error: %s", error_msg);
}

ScriptEffect::~ScriptEffect() {
    tcc_delete(state);
}

void ScriptEffect::setCode(std::string code) {
    last_error.clear();
    crashed = false;

    if (code.empty()) {
        is_loaded = false;
        this->code.clear();

        if (state) {
            tcc_delete(state);
            state = nullptr;
        }

        process_func = nullptr;
        params_func = nullptr;

        return;
    }

    if (state) {
        tcc_delete(state);
        state = nullptr;
    }

    {
        state = tcc_new();
        tcc_set_output_type(state, TCC_OUTPUT_MEMORY);
        tcc_set_error_func(state, nullptr, ScriptEffect::errorHandle);

        ensureTccAssetsAvailable();

        std::string cacheDir = g_cache_dir;
        
        tcc_add_include_path(state, (cacheDir + "/include").c_str());
        tcc_set_lib_path(state, cacheDir.c_str());

        tcc_set_options(state, "-std=c99 -nostdlib -DTCC_MATH");

        tcc_add_library_path(state, "/system/lib64");

        tcc_add_library(state, "dl");
    }

    std::string fullCode = prependHeaders(code);

    if (tcc_compile_string(state, fullCode.c_str()) == -1) {
        is_loaded = false;
        return;
    }

    tcc_add_file(state, g_libtcc1_path.c_str());

    registerAllSymbols(state);

    if (tcc_relocate(state) == -1) {
        is_loaded = false;
        return;
    }

    auto run_handle = tcc_get_symbol(state, "run");
    auto params_handle = tcc_get_symbol(state, "setParams");

    if (!run_handle || !params_handle) {
        is_loaded = false;
        return;
    }

    process_func = (void (*)(float*, float*, float*, float*))run_handle;
    params_func = (void (*)(ScriptParams*))params_handle;

    this->code = std::move(code);
    is_loaded = true;
}

void ScriptEffect::setParams(ScriptParamsArray params) {
    std::memcpy(this->params, params, sizeof(ScriptParamsArray));

    if (!is_loaded || !params_func) {
        return;
    }

    params_func(params);
}

void ScriptEffect::run(std::vector<std::vector<float>>& audio) {
    if (!is_loaded || !process_func || crashed) {
        return;
    }

    // Install crash handler
    struct sigaction sa;
    sa.sa_handler = script_crash_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGSEGV, &sa, &g_old_sigsegv_handler);
    sigaction(SIGBUS, &sa, &g_old_sigbus_handler);

    g_script_crashed = false;

    if (sigsetjmp(g_script_jmp_buf, 1) == 0) {
        process_func(audio[0].data(), audio[1].data(), audio[0].data(), audio[1].data());
    } else {
        // Crashed! Disable this script
        crashed = true;
        is_loaded = false;
        LOG_D("ScriptEffect: runtime crash detected, script disabled");
        last_error = "Runtime crash (SIGSEGV/SIGBUS). Script has been disabled. Check for buffer overflows or invalid pointer access.";
    }

    // Restore original handlers
    sigaction(SIGSEGV, &g_old_sigsegv_handler, nullptr);
    sigaction(SIGBUS, &g_old_sigbus_handler, nullptr);
}

void ScriptEffect::copyParamsFrom(const ScriptEffect& other) {
    std::memcpy(params, other.params, sizeof(params));
    code = other.code;

    this->setCode(code);
    this->setParams(params);
    this->setEnabled(other.isEnabled());
}

Priority ScriptEffect::priority() const {
    return Priority::SCRIPT_EFFECT;
}

void ScriptEffect::reset() {
    last_error.clear();
    code.clear();

    if (state) {
        tcc_delete(state);
        state = nullptr;
    }

    is_loaded = false;
    crashed = false;
    process_func = nullptr;
    params_func = nullptr;

    std::memset(params, 0, sizeof(params));
}
