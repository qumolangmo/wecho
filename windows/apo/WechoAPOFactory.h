#pragma once

#include <Unknwnbase.h>
#include "WechoAPO.h"

class WechoAPOFactory : public IClassFactory {
public:
    STDMETHOD(QueryInterface) (REFIID riid, void** ppv) override;
    STDMETHOD_(ULONG, AddRef)() override;
    STDMETHOD_(ULONG, Release)() override;

    STDMETHOD(CreateInstance)(IUnknown* pUnkOuter, REFIID riid, void** ppv) override;
    STDMETHOD(LockServer)(BOOL fLock) override;
    static long lock_count;
private:
    ULONG ref_count = 1;
};

