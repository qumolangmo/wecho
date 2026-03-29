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