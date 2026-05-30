/*
 * Copyright (C) 2026 qumolangmo
 *
 * This file is part of Wecho.
 *
 * Wecho is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Wecho is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Wecho.  If not, see <https://www.gnu.org/licenses/>.
 */

#include "flutter_window.h"

#include <debugapi.h>
#include <optional>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <variant>

#include "flutter/generated_plugin_registrant.h"
#include "apoBridge.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  
  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);

  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }

  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  RegisterMethodChannelHandlers();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::RegisterMethodChannelHandlers() {
  auto* engine = flutter_controller_->engine();

  flutter::MethodChannel<flutter::EncodableValue> channel(
    engine->messenger(), "audio_capture",
    &flutter::StandardMethodCodec::GetInstance()
  );

  channel.SetMethodCallHandler([](const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    
    const std::string& method = call.method_name();
    
    if (method == "initAPOBridge") {
      bool success = wecho::APOBridge::getInstance().initialize();
      result->Success(flutter::EncodableValue(success));
    }
    else if (method == "setAPOEffectParam") {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args) {
        auto paramId_it = args->find(flutter::EncodableValue("paramId"));
        auto value_it = args->find(flutter::EncodableValue("value"));
        
        if (paramId_it != args->end() && value_it != args->end()) {
          int paramId = static_cast<int>(std::get<int>(paramId_it->second));

          if (std::holds_alternative<double>(value_it->second)) {
            float value = static_cast<float>(std::get<double>(value_it->second));
            wecho::APOBridge::getInstance().updateEffectParam(
              static_cast<ParamID>(paramId), value);
          } else if (std::holds_alternative<bool>(value_it->second)) {
            bool value = std::get<bool>(value_it->second);
            wecho::APOBridge::getInstance().updateEffectParam(
              static_cast<ParamID>(paramId), value);
          } else if (std::holds_alternative<int>(value_it->second)) {
            int value = static_cast<int>(std::get<int>(value_it->second));
            wecho::APOBridge::getInstance().updateEffectParam(
              static_cast<ParamID>(paramId), value);
          } else if (std::holds_alternative<std::string>(value_it->second)) {
            std::string value = std::get<std::string>(value_it->second);
            wecho::APOBridge::getInstance().updateEffectParam(
              static_cast<ParamID>(paramId), value);
          }

          result->Success();
        } else {
          result->Error("INVALID_ARGUMENTS", "Missing paramId or value");
        }
      } else {
        result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
      }
    }
    else if (method == "setAPOMasterEnabled") {
      if (std::holds_alternative<bool>(*call.arguments())) {
        bool enabled = std::get<bool>(*call.arguments());
        wecho::APOBridge::getInstance().setProcessorEnabled(enabled);
        result->Success();
      } else {
        result->Error("INVALID_ARGUMENTS", "Value must be a boolean");
      }
    }
    else if (method == "commitAPO") {
      wecho::APOBridge::getInstance().commit();
      result->Success();
    }
    else {
      result->NotImplemented();
    }
  });
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
