#include "effect.hpp"
#include <dlfcn.h>
#include <fstream>
#include <sstream>

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

        tcc_set_options(state, "-std=c99 -nostdlib");

        tcc_add_library_path(state, "/system/lib64");

        tcc_add_library(state, "c");
        tcc_add_library(state, "m");
        tcc_add_library(state, "dl");
    }

    std::string fullCode = prependHeaders(code);

    if (tcc_compile_string(state, fullCode.c_str()) == -1) {
        is_loaded = false;
        return;
    }

    tcc_add_file(state, g_libtcc1_path.c_str());

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
