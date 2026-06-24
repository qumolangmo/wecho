#include "effect.hpp"
#include "../scripting/wecho_dsp_c_api.h"
#include <dlfcn.h>
#include <fstream>
#include <sstream>

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
        /* biquad */
        {"get_biquad",            (void*)&get_biquad},
        {"biquad_reset",          (void*)&biquad_reset},
        {"biquad_set_hp",         (void*)&biquad_set_hp},
        {"biquad_set_lp",         (void*)&biquad_set_lp},
        {"biquad_set_peak",       (void*)&biquad_set_peak},
        {"biquad_process",        (void*)&biquad_process},
        {"biquad_process_block",  (void*)&biquad_process_block},
        /* delay line */
        {"get_delay_line_1024",            (void*)&get_delay_line_1024},
        {"delay_line_1024_reset",          (void*)&delay_line_1024_reset},
        {"delay_line_1024_set_delay",      (void*)&delay_line_1024_set_delay},
        {"delay_line_1024_process",        (void*)&delay_line_1024_process},
        {"delay_line_1024_process_block",  (void*)&delay_line_1024_process_block},
        {"delay_line_1024_read",           (void*)&delay_line_1024_read},
        {"delay_line_1024_read_block",     (void*)&delay_line_1024_read_block},
        {"delay_line_1024_write",          (void*)&delay_line_1024_write},
        {"delay_line_1024_write_block",    (void*)&delay_line_1024_write_block},
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
    };
    for (auto& s : syms) {
        tcc_add_symbol(state, s.name, s.addr);
    }
}

std::string ScriptEffect::last_error;
static std::string g_cache_dir;

static std::string g_libtcc1_path;
static std::string g_tcclib_h;
static std::string g_wecho_dsp_c_api_h;

void ScriptEffect::setCacheDir(std::string_view cache_dir) {
    g_cache_dir = std::string(cache_dir);
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

    if (is_loaded) {
        if (state) {
            tcc_delete(state);
            state = nullptr;
        }
    }

    if (!state) {
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
    if (!is_loaded || !params_func) {
        return;
    }

    params_func(params);
}

void ScriptEffect::run(std::vector<std::vector<float>>& audio) {
    if (!is_loaded || !process_func) {
        return;
    }

    process_func(audio[0].data(), audio[1].data(), audio[0].data(), audio[1].data());
}

void ScriptEffect::copyParamsFrom(const ScriptEffect& other) {
    std::memcpy(params, other.params, sizeof(params));
    code = other.code;

    this->setParams(params);
    this->setCode(code);
    this->setEnabled(other.isEnabled());
}

Priority ScriptEffect::priority() const {
    return Priority::SCRIPT_EFFECT;
}

void ScriptEffect::reset() {
    // Script effect doesn't have internal state to reset,
    // but we keep this to satisfy the interface.
}
