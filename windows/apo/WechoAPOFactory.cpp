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

#include "WechoAPOFactory.h"

long WechoAPOFactory::lock_count = 0;

STDMETHODIMP WechoAPOFactory::CreateInstance(IUnknown* pUnkOuter, REFIID riid, void** ppv) {
    HRESULT result;

    if (ppv == nullptr) {
        return E_POINTER;
    }

    if (pUnkOuter != nullptr && riid != __uuidof(IUnknown)) {
        return E_NOINTERFACE;
    }

    WechoAPO* apo = new(std::nothrow) WechoAPO(pUnkOuter);
    
    if (apo == nullptr) {
        return E_OUTOFMEMORY;
    }
    
    result = apo->NonDelegatingQueryInterface(riid, ppv);

    apo->NonDelegatingRelease();
    return result;
}

STDMETHODIMP WechoAPOFactory::LockServer(BOOL fLock) {
    if (fLock) {
        InterlockedIncrement(&lock_count);
    } else {
        InterlockedDecrement(&lock_count);
    }
    return S_OK;
}

STDMETHODIMP WechoAPOFactory::QueryInterface(REFIID iid, void** ppv) {
    if (ppv == nullptr) return E_POINTER;

    if (iid == __uuidof(IClassFactory) || iid == __uuidof(IUnknown)) {
        *ppv = static_cast<IClassFactory*>(this);
    } else {
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    static_cast<IUnknown*>(*ppv)->AddRef();
    return S_OK;
}

STDMETHODIMP_(ULONG) WechoAPOFactory::AddRef() {
    return InterlockedIncrement(&ref_count);
}

STDMETHODIMP_(ULONG) WechoAPOFactory::Release() {
    if (InterlockedDecrement(&ref_count) == 0) {
        delete this;
        return 0;
    }
    return ref_count;
}